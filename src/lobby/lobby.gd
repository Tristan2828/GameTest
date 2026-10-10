class_name Lobby
extends CanvasLayer
## Pre-run lobby: everyone picks a character and readies up; the host starts.
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

var _state: LobbyState = LobbyState.new()
## Host: clients whose lobby has loaded (can receive state).
var _ready_peers: Dictionary[int, bool] = {}
var _open_seconds: float = 0.0
var _copied_feedback_left: float = 0.0
var _autopilot_readied: bool = false

@onready var _cards: Array[Button] = [%Card0, %Card1, %Card2, %Card3]
@onready var _players_label: Label = %PlayersLabel
@onready var _ready_button: Button = %ReadyButton
@onready var _start_button: Button = %StartButton
@onready var _status_label: Label = %StatusLabel
@onready var _config_label: Label = %ConfigLabel
@onready var _difficulty_button: Button = %DifficultyButton
@onready var _custom_button: Button = %CustomButton
@onready var _center: Control = $Center
var _difficulty: DifficultyScreen = null
var _custom_game: CustomGameScreen = null


func _ready() -> void:
	for i: int in _cards.size():
		var stats := Characters.get_character(i)
		(_cards[i].get_node("Lines/Name") as Label).text = stats.display_name
		(_cards[i].get_node("Lines/Blurb") as Label).text = stats.blurb
		(_cards[i].get_node("Lines/Ability") as Label).text = "%s: %s" % [stats.ability_name, stats.ability_description]
		(_cards[i].get_node("Portrait") as CharacterPortrait).character_id = i
		_cards[i].pressed.connect(_choose_locally.bind(i))
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
	_cards[RunSetup.character_for(multiplayer.get_unique_id())].grab_focus()
	_refresh()
	if not LaunchOptions.screenshot_dir.is_empty():
		await get_tree().create_timer(0.3).timeout
		await Main.save_screenshot(get_tree(), "lobby.png")
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
	var mine: int = _state.characters.get(me, RunSetup.character_for(me))
	for i: int in _cards.size():
		_cards[i].button_pressed = i == mine
		var portrait := _cards[i].get_node("Portrait") as CharacterPortrait
		portrait.color = _color_for(me)
		var pickers: Array[Color] = []
		for peer_id: int in _state.order:
			if _state.characters[peer_id] == i:
				pickers.append(_color_for(peer_id))
		portrait.pickers = pickers
	var lines := PackedStringArray()
	for peer_id: int in _state.order:
		var role := "host" if peer_id == 1 else ("ready" if _state.ready.get(peer_id, false) else "not ready")
		var you := "  (you)" if peer_id == me else ""
		lines.append("%s: %s, %s%s" % [_name_for(peer_id), Characters.get_character(_state.characters[peer_id]).display_name, role, you])
	_players_label.text = "\n".join(lines)
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


## Players are named by their slot color, in join order (same order the arena uses).
func _name_for(peer_id: int) -> String:
	var index := maxi(_state.order.find(peer_id), 0)
	return Player.SLOT_NAMES[index % Player.SLOT_NAMES.size()]


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
