class_name LevelUpPanel
extends Control
## The level-up choice cards (v0.23.0: weapons, weapon levels and passives; see
## Cards). Works with mouse (click) and gamepad/keyboard (focus moves between
## cards; A, Enter or the left trigger picks, so one hand on the left side of
## a gamepad is enough). After you pick, your card stays lit with a gold border
## while the others dim; until everyone has chosen you can still pick another
## card (v0.24.0). Below the cards: Reroll (uses one of your card rerolls; the
## shop sells more). Every card grows to fit its text, all to the same height.

signal picked(card: int)
signal reroll_pressed

@onready var _title: Label = %LevelUpTitle
@onready var _cards: HBoxContainer = %Cards
@onready var _status: Label = %LevelUpStatus

const UNPICKED_MODULATE: Color = Color(0.55, 0.52, 0.6, 1.0)
const BADGE_COLOR: Color = Color(1.0, 0.85, 0.4)
const EVOLUTION_COLOR: Color = Color(0.6, 1.0, 0.6)
## Icon frame colors: weapons, passives, evolutions, fillers.
const WEAPON_FRAME: Color = Color(0.95, 0.72, 0.35)
const PASSIVE_FRAME: Color = Color(0.45, 0.75, 1.0)
const FILLER_FRAME: Color = Color(0.6, 0.57, 0.68)
## Shortest a card gets; taller when its text needs it (all cards match).
const CARD_MIN_HEIGHT: float = 112.0
## Lines' offsets inside a card (top + bottom), see hud.tscn.
const CARD_PADDING: float = 14.0

var _offered: Array[int] = []
var _pips: Array[LevelPips] = []
## The card's icon at the top of each card.
var _icons: Array[SpriteIcon] = []
## "New weapon!" / "New passive!" / "Evolution!" under the title.
var _badges: Array[Label] = []
var _reroll_button: Button = null
## The pressed-card look (gold border), reused to mark your pick.
var _picked_style: StyleBox = null
## The card you picked this round (-1 = none yet).
var _picked: int = -1
static var _screenshot_taken: bool = false
static var _picked_screenshot_taken: bool = false


## Shows these cards. `player` (this machine's, may be null) fills in each card's
## level and preview; `rerolls` is how many card rerolls they have left.
func open(level: int, offered: Array[int], player: Player = null, rerolls: int = 0) -> void:
	_offered = offered
	_picked = -1
	_title.text = "Level %d! Choose one" % level
	var stats := player.stats if player != null else null
	var buttons := _cards.get_children()
	for i: int in buttons.size():
		var button := buttons[i] as Button
		button.visible = i < offered.size()
		button.disabled = false
		button.modulate = Color.WHITE
		_clear_picked_look(button)
		if i >= offered.size():
			continue
		var card := offered[i]
		(button.get_node("Lines/Title") as Label).text = Cards.title(card, stats)
		(button.get_node("Lines/Description") as Label).text = Cards.description(card, player)
		_icons[i].sprite = PixelArt.big_icon(Cards.icon(card, stats))
		_icons[i].frame = frame_color(card)
		_icons[i].queue_redraw()
		_badges[i].text = Cards.badge(card, player)
		_badges[i].modulate = EVOLUTION_COLOR if Cards.is_evolution(card) else BADGE_COLOR
		_badges[i].visible = not _badges[i].text.is_empty()
		var levels := Cards.levels(card, player)
		_pips[i].visible = levels.y > 0 and _badges[i].text.is_empty()
		_pips[i].owned = levels.x
		_pips[i].maximum = levels.y
		(button.get_node("Lines/Level") as Label).visible = false
		(button.get_node("Lines/Preview") as Label).text = Cards.preview_text(card, player)
	set_rerolls(rerolls)
	show()
	_fit_cards()
	Sfx.play(&"level_up", -4.0)
	if not offered.is_empty():
		(buttons[0] as Button).grab_focus()
	if not _screenshot_taken and not LaunchOptions.screenshot_dir.is_empty():
		_screenshot_taken = true
		for i: int in 3:
			await get_tree().process_frame  # After _fit_cards.
		set_status("Pick one!")
		Main.save_screenshot(get_tree(), "level_up.png")


## The icon frame's color for a card: gold weapons, blue passives, green
## evolutions, grey fillers.
static func frame_color(card: int) -> Color:
	if Cards.is_evolution(card):
		return EVOLUTION_COLOR
	if Cards.is_upgrade(card):
		return PASSIVE_FRAME if Upgrades.get_upgrade(card).passive else FILLER_FRAME
	return WEAPON_FRAME


func set_status(text: String) -> void:
	_status.text = text


func set_rerolls(rerolls: int) -> void:
	_reroll_button.text = "Reroll (%d left)" % rerolls if rerolls > 0 else "No rerolls (buy them in the shop)"
	_reroll_button.disabled = rerolls <= 0 or _picked >= 0


## Your pick stays highlighted (gold border, others dimmed) while the rest of
## the team is still choosing. The dimmed cards can still be picked instead.
func mark_picked(card: int) -> void:
	_picked = card
	var index := _offered.find(card)
	var buttons := _cards.get_children()
	for i: int in buttons.size():
		var button := buttons[i] as Button
		_clear_picked_look(button)
		if i == index:
			for style: StringName in [&"normal", &"hover", &"pressed"]:
				button.add_theme_stylebox_override(style, _picked_style)
			button.modulate = Color.WHITE
		else:
			button.modulate = UNPICKED_MODULATE
	_reroll_button.disabled = true
	if index >= 0 and index < buttons.size():
		(buttons[index] as Button).grab_focus()
	if not _picked_screenshot_taken and not LaunchOptions.screenshot_dir.is_empty():
		_picked_screenshot_taken = true
		await get_tree().process_frame
		Main.save_screenshot(get_tree(), "level_up_picked.png")


func _clear_picked_look(button: Button) -> void:
	for style: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		button.remove_theme_stylebox_override(style)


## Every card as tall as the tallest one's text needs (never shorter than
## CARD_MIN_HEIGHT). Wrapped labels only know their height once laid out at the
## card's width, hence the frame waits.
func _fit_cards() -> void:
	var buttons := _cards.get_children()
	for button: Node in buttons:
		(button as Button).custom_minimum_size.y = CARD_MIN_HEIGHT
	await get_tree().process_frame
	await get_tree().process_frame
	var tallest := CARD_MIN_HEIGHT
	for button: Node in buttons:
		var card := button as Button
		if card.visible:
			tallest = maxf(tallest, (card.get_node("Lines") as Control).get_combined_minimum_size().y + CARD_PADDING)
	for button: Node in buttons:
		(button as Button).custom_minimum_size.y = ceilf(tallest)


func _ready() -> void:
	var buttons := _cards.get_children()
	_picked_style = (buttons[0] as Button).get_theme_stylebox("pressed")
	for i: int in buttons.size():
		var button := buttons[i] as Button
		button.pressed.connect(_on_card_pressed.bind(i))
		var lines := button.get_node("Lines")
		# Long titles and previews wrap instead of running past the card's border.
		for label_name: String in ["Title", "Description", "Preview"]:
			(lines.get_node(label_name) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var pips := LevelPips.new()
		pips.visible = false
		lines.add_child(pips)
		lines.move_child(pips, 1)  # Right under the title.
		_pips.append(pips)
		var badge := Label.new()
		badge.add_theme_font_size_override("font_size", 9)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.visible = false
		lines.add_child(badge)
		lines.move_child(badge, 1)
		_badges.append(badge)
		var icon := SpriteIcon.new("", Vector2(36, 36))
		icon.frame_size = Vector2(36, 36)
		icon.max_scale = 3
		lines.add_child(icon)
		lines.move_child(icon, 0)  # Above the title.
		_icons.append(icon)
	_reroll_button = Button.new()
	_reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll_button.add_theme_font_size_override("font_size", 9)
	_reroll_button.pressed.connect(func() -> void: reroll_pressed.emit())
	var box := _status.get_parent()
	box.add_child(_reroll_button)
	box.move_child(_reroll_button, _status.get_index())


## The left trigger picks the focused card, like A (one-handed play).
func _process(_delta: float) -> void:
	if not visible or not Input.is_action_just_pressed(&"pick_card"):
		return
	var focused := get_viewport().gui_get_focus_owner()
	var buttons := _cards.get_children()
	for i: int in buttons.size():
		if buttons[i] == focused:
			_on_card_pressed(i)
			return


func _on_card_pressed(index: int) -> void:
	if index >= _offered.size() or _offered[index] == _picked:
		return
	picked.emit(_offered[index])
