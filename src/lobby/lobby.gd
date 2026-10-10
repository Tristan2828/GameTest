class_name Lobby
extends CanvasLayer
## Pre-run lobby: everyone picks a character and readies up; the host starts.
##
## The main page is the party: one card per player (their name, hero walking on
## the spot, ability, hearts and ready state). Your own card (or Choose Hero)
## opens the hero picker sub-screen with all four heroes.
##
## The host owns the lobby state and broadcasts it whenever it changes. Clients
## send their choice and ready flag. Spawned by Main's LevelSpawner like the
## arena, so friends who join now land here automatically.
##
## The host also sets the run's Difficulty and Custom Game options (RunConfig,
## kept in RunSetup.config); clients get them with the lobby state and can look
## at both pages read-only.

signal start_requested

## Autopilot (test mode): the host starts on its own once everyone is ready and
## the lobby has been open at least this long; clients ready up after a moment.
const AUTOPILOT_HOST_MIN_SECONDS: float = 4.0
const AUTOPILOT_CLIENT_DELAY: float = 0.5
const COPIED_FEEDBACK_SECONDS: float = 4.0
const PARTY_CARD_SIZE: Vector2 = Vector2(148, 178)
const LABEL_COLOR: Color = Color(0.6, 0.57, 0.68)
const VALUE_COLOR: Color = Color(0.95, 0.93, 1.0)
const ABILITY_COLOR: Color = Color(0.95, 0.78, 0.4)
const HEARTS_COLOR: Color = Color(0.95, 0.45, 0.5)
const READY_COLOR: Color = Color(0.55, 0.95, 0.5)
const CARD_BG: Color = Color(0.1, 0.08, 0.14)

var _state: LobbyState = LobbyState.new()
## Host: clients whose lobby has loaded (can receive state).
var _ready_peers: Dictionary[int, bool] = {}
var _open_seconds: float = 0.0
var _copied_feedback_left: float = 0.0
var _autopilot_readied: bool = false

@onready var _cards: Array[Button] = [%Card0, %Card1, %Card2, %Card3]
@onready var _party: HBoxContainer = %Party
@onready var _picker: Control = %Picker
@onready var _hero_button: Button = %HeroButton
@onready var _back_button: Button = %BackButton
@onready var _ready_button: Button = %ReadyButton
@onready var _start_button: Button = %StartButton
@onready var _status_label: Label = %StatusLabel
@onready var _config_label: Label = %ConfigLabel
@onready var _difficulty_button: Button = %DifficultyButton
@onready var _custom_button: Button = %CustomButton
@onready var _center: Control = $Center
var _difficulty: DifficultyScreen = null
var _custom_game: CustomGameScreen = null
## What the party cards were last built from (rebuilt only when it changes).
var _party_signature: String = ""
## Your own party card (opens the hero picker).
var _my_card: Button = null


func _ready() -> void:
	for i: int in _cards.size():
		var stats := Characters.get_character(i)
		(_cards[i].get_node("Lines/Name") as Label).text = stats.display_name
		(_cards[i].get_node("Lines/Blurb") as Label).text = stats.blurb
		(_cards[i].get_node("Lines/Ability") as Label).text = "%s: %s" % [stats.ability_name, stats.ability_description]
		(_cards[i].get_node("Portrait") as CharacterPortrait).character_id = i
		_cards[i].pressed.connect(func() -> void:
			_choose_locally(i)
			_close_picker())
	_hero_button.pressed.connect(_open_picker)
	_back_button.pressed.connect(_close_picker)
	_ready_button.toggled.connect(_set_ready_locally)
	_start_button.pressed.connect(_start_locally)
	var is_host := multiplayer.is_server()
	_start_button.visible = is_host
	_ready_button.visible = not is_host
	if is_host:
		# Automated runs (autopilot) always use the defaults, not your saved choices.
		RunSetup.config = RunConfig.new() if LaunchOptions.autopilot else RunConfig.load_saved()
		if not LaunchOptions.run_config.is_empty():
			var merged := RunSetup.config.to_dict()
			merged.merge(LaunchOptions.run_config, true)
			RunSetup.config = RunConfig.from_dict(merged)
	_setup_config_screens(is_host)
	if is_host:
		_state.add(1, RunSetup.character_for(1))
		for peer_id: int in RunSetup.order:
			if multiplayer.get_peers().has(peer_id):
				_state.add(peer_id, RunSetup.character_for(peer_id))
		for peer_id: int in multiplayer.get_peers():
			_state.add(peer_id, RunSetup.character_for(peer_id))
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	else:
		_notify_ready.rpc_id(1)
	_refresh()
	if _my_card != null:
		_my_card.grab_focus()
	if not LaunchOptions.screenshot_dir.is_empty():
		await get_tree().create_timer(0.3).timeout
		await Main.save_screenshot(get_tree(), "lobby.png")
		if not is_inside_tree():
			return
		_open_picker()
		await get_tree().create_timer(0.2).timeout
		if not is_inside_tree():
			return
		await Main.save_screenshot(get_tree(), "lobby_heroes.png")
		_close_picker()
		for page: Array in [[_difficulty_button, _difficulty, "lobby_difficulty.png"], [_custom_button, _custom_game, "lobby_custom.png"]]:
			if not is_inside_tree():
				return  # Autopilot already started the run.
			(page[0] as Button).pressed.emit()
			await get_tree().create_timer(0.2).timeout
			if not is_inside_tree():
				return
			await Main.save_screenshot(get_tree(), page[2])
			(page[1] as RunConfigScreen).close()


func _setup_config_screens(is_host: bool) -> void:
	_difficulty = DifficultyScreen.new()
	_custom_game = CustomGameScreen.new()
	for page: Array in [[_difficulty, _difficulty_button], [_custom_game, _custom_button]]:
		var screen: RunConfigScreen = page[0]
		var button: Button = page[1]
		screen.editable = is_host
		add_child(screen)
		screen.config_changed.connect(_on_config_changed)
		button.pressed.connect(func() -> void:
			screen.config = RunSetup.config
			_center.hide()
			screen.open())
		screen.closed.connect(func() -> void:
			_center.show()
			button.grab_focus())


## Host: a difficulty or custom game value changed.
func _on_config_changed() -> void:
	RunSetup.config.save()
	_broadcast()


func _process(delta: float) -> void:
	_open_seconds += delta
	_copied_feedback_left = maxf(_copied_feedback_left - delta, 0.0)
	_refresh()
	if LaunchOptions.autopilot and multiplayer.is_server() and _open_seconds >= _autopilot_min_seconds() \
			and _state.can_start(1):
		_start_locally()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("copy_invite") and Net.invite.copy_to_clipboard():
		_copied_feedback_left = COPIED_FEEDBACK_SECONDS
	elif _picker.visible and event.is_action_pressed("ui_cancel"):
		_close_picker()
		get_viewport().set_input_as_handled()


## The hero picker sub-screen (all four heroes; picking one goes back to the party).
func _open_picker() -> void:
	_center.hide()
	_picker.show()
	_cards[_my_character()].grab_focus()


func _close_picker() -> void:
	if not _picker.visible:
		return
	_picker.hide()
	_center.show()
	_party_signature = ""  # Rebuild now, so the card shows the new hero right away.
	_refresh()
	if _my_card != null:
		_my_card.grab_focus()


func _my_character() -> int:
	var me := multiplayer.get_unique_id()
	return _state.characters.get(me, RunSetup.character_for(me))


## Text summary for headless smoke tests.
func debug_report() -> String:
	var parts := PackedStringArray()
	for peer_id: int in _state.order:
		parts.append("%d:%s%s" % [peer_id, Characters.get_character(_state.characters[peer_id]).display_name,
			"(ready)" if _state.ready.get(peer_id, false) else ""])
	return "[report] peer %d in lobby: %s" % [multiplayer.get_unique_id(), ", ".join(parts)]


func _autopilot_min_seconds() -> float:
	# Solo has nobody to wait for.
	return AUTOPILOT_HOST_MIN_SECONDS if Net.is_online() else 0.5


func _refresh() -> void:
	var me := multiplayer.get_unique_id()
	var mine := _my_character()
	_refresh_party(me)
	for i: int in _cards.size():
		_cards[i].button_pressed = i == mine
		var portrait := _cards[i].get_node("Portrait") as CharacterPortrait
		portrait.color = _color_for(me)
		var pickers: Array[Color] = []
		for peer_id: int in _state.order:
			if _state.characters[peer_id] == i:
				pickers.append(_color_for(peer_id))
		portrait.pickers = pickers
	_config_label.text = RunSetup.config.summary()
	for i: int in _cards.size():
		var hearts := maxi(Characters.get_character(i).max_hearts + RunSetup.config.hearts_bonus, 1)
		(_cards[i].get_node("Lines/Hearts") as Label).text = "%d hearts" % hearts
	if multiplayer.is_server():
		var waiting := _state.not_ready(1)
		_start_button.disabled = not waiting.is_empty()
		var status := "Press Start when everyone is ready." if waiting.is_empty() else "Waiting for %d player(s) to ready up." % waiting.size()
		if Net.is_online() and not LaunchOptions.local_only:
			var invite := Net.invite.address
			var hint := "copied!" if _copied_feedback_left > 0.0 else "F1 to copy"
			status = ("Invite: %s (%s)\n" % [invite, hint] if not invite.is_empty() else "Invite: finding your address...\n") + status
		_status_label.text = status
	else:
		_status_label.text = "Pick a character and press Ready. The host starts the run."


## Rebuilds the party cards when someone joins, leaves, picks, readies or
## their name arrives (not every frame: the portraits animate on their own).
func _refresh_party(me: int) -> void:
	var signature := "%s|%s|%s|%s|%d|%d" % [_state.order, _state.characters, _state.ready, Net.names, me,
		RunSetup.config.hearts_bonus]
	if signature == _party_signature:
		return
	_party_signature = signature
	var had_focus := _my_card != null and _my_card.has_focus()
	for child: Node in _party.get_children():
		_party.remove_child(child)
		child.queue_free()
	_my_card = null
	for peer_id: int in _state.order:
		_party.add_child(_party_card(peer_id, me))
	if had_focus and _my_card != null:
		_my_card.grab_focus()


## One player's card: name, hero walking on the spot, ability, hearts, ready state.
## Your own card is a button that opens the hero picker.
func _party_card(peer_id: int, me: int) -> Button:
	var color := _color_for(peer_id)
	var character := Characters.get_character(_state.characters[peer_id])
	var mine := peer_id == me
	var is_ready: bool = _state.ready.get(peer_id, false)
	var card := Button.new()
	card.custom_minimum_size = PARTY_CARD_SIZE
	var box := StyleBoxFlat.new()
	box.bg_color = CARD_BG
	box.border_color = color.darkened(0.25)
	box.set_border_width_all(1)
	card.add_theme_stylebox_override("normal", box)
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = CARD_BG.lightened(0.08)
	hover.border_color = color
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	if mine:
		_my_card = card
		card.tooltip_text = "Change hero"
		card.pressed.connect(_open_picker)
	else:
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lines := VBoxContainer.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.offset_left = 6.0
	lines.offset_top = 5.0
	lines.offset_right = -6.0
	lines.offset_bottom = -5.0
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 2)
	card.add_child(lines)
	var title := _name_for(peer_id)
	var name_label := _card_label(title, color)
	# Big letters when the name fits the card.
	var wide := ThemeDB.fallback_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	if wide <= PARTY_CARD_SIZE.x - 14.0:
		name_label.add_theme_font_size_override("font_size", 18)
	lines.add_child(name_label)
	if mine and _state.order.size() > 1:
		lines.add_child(_card_label("(you)", LABEL_COLOR))
	var portrait := CharacterPortrait.new()
	portrait.character_id = _state.characters[peer_id]
	portrait.color = color
	portrait.scale_factor = 3.0
	portrait.custom_minimum_size = Vector2(0, 58)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.walk_offset = _state.order.find(peer_id) * 0.7
	portrait.animate = true
	lines.add_child(portrait)
	lines.add_child(_card_label(character.display_name, VALUE_COLOR))
	var ability := _card_label("%s: %s" % [character.ability_name, character.ability_description], ABILITY_COLOR)
	ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lines.add_child(ability)
	var hearts := maxi(character.max_hearts + RunSetup.config.hearts_bonus, 1)
	lines.add_child(_card_label("%d hearts" % hearts, HEARTS_COLOR))
	var status := "HOST" if peer_id == 1 else ("READY" if is_ready else "not ready")
	var status_color := ABILITY_COLOR if peer_id == 1 else (READY_COLOR if is_ready else LABEL_COLOR)
	if mine:
		status += "  -  change hero"
	lines.add_child(_card_label(status, status_color))
	return card


func _card_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A player's chosen name, or their slot color in join order (same order the arena uses).
func _name_for(peer_id: int) -> String:
	return Net.name_of(peer_id, maxi(_state.order.find(peer_id), 0))


func _color_for(peer_id: int) -> Color:
	var index := maxi(_state.order.find(peer_id), 0)
	return Player.SLOT_COLORS[index % Player.SLOT_COLORS.size()]


func _choose_locally(character: int) -> void:
	if multiplayer.is_server():
		_host_choose(multiplayer.get_unique_id(), character)
	else:
		_state.choose(multiplayer.get_unique_id(), character)
		_request_choose.rpc_id(1, character)


func _set_ready_locally(is_ready: bool) -> void:
	if not multiplayer.is_server():
		_request_ready.rpc_id(1, is_ready)


func _start_locally() -> void:
	if not multiplayer.is_server() or not _state.can_start(1):
		return
	RunSetup.characters = _state.characters.duplicate()
	RunSetup.order = _state.order.duplicate()
	set_process(false)
	start_requested.emit()


# --- Host ----------------------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	_state.add(peer_id, RunSetup.character_for(peer_id))
	_broadcast()


func _on_peer_disconnected(peer_id: int) -> void:
	_state.remove(peer_id)
	_ready_peers.erase(peer_id)
	_broadcast()


func _host_choose(peer_id: int, character: int) -> void:
	if _state.choose(peer_id, character):
		_broadcast()


func _broadcast() -> void:
	var ids := PackedInt32Array(_state.order)
	var characters := PackedInt32Array()
	var readies := PackedByteArray()
	for peer_id: int in _state.order:
		characters.append(_state.characters[peer_id])
		readies.append(1 if _state.ready.get(peer_id, false) else 0)
	var config := RunSetup.config.to_dict()
	for peer_id: int in _ready_peers:
		_receive_state.rpc_id(peer_id, ids, characters, readies, config)


# --- Network messages ------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _notify_ready() -> void:
	if multiplayer.is_server():
		_ready_peers[multiplayer.get_remote_sender_id()] = true
		_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func _request_choose(character: int) -> void:
	if multiplayer.is_server():
		_host_choose(multiplayer.get_remote_sender_id(), character)


@rpc("any_peer", "call_remote", "reliable")
func _request_ready(is_ready: bool) -> void:
	if multiplayer.is_server():
		_state.set_ready(multiplayer.get_remote_sender_id(), is_ready)
		_broadcast()


@rpc("authority", "call_remote", "reliable")
func _receive_state(ids: PackedInt32Array, characters: PackedInt32Array, readies: PackedByteArray,
		config: Dictionary) -> void:
	RunSetup.config = RunConfig.from_dict(config)
	for screen: RunConfigScreen in [_difficulty, _custom_game]:
		screen.show_config(RunSetup.config)
	var fresh := LobbyState.new()
	for i: int in ids.size():
		fresh.add(ids[i], characters[i])
		fresh.set_ready(ids[i], readies[i] != 0)
	_state = fresh
	_ready_button.set_pressed_no_signal(_state.ready.get(multiplayer.get_unique_id(), false))
	if LaunchOptions.autopilot and not _autopilot_readied:
		_autopilot_readied = true
		get_tree().create_timer(AUTOPILOT_CLIENT_DELAY).timeout.connect(func() -> void:
			var pick := LaunchOptions.character if Characters.is_valid_id(LaunchOptions.character) else randi() % Characters.ALL.size()
			_choose_locally(pick)
			_ready_button.button_pressed = true)
