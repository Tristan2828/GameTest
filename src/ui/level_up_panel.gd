class_name LevelUpPanel
extends Control
## The level-up choice cards (v0.23.0: weapons, weapon levels and passives; see
## Cards). Works with mouse (click) and gamepad/keyboard (focus moves between
## cards; confirm picks). After you pick, your card stays lit with a gold border
## while the others dim, until everyone has chosen. Below the cards: Reroll
## (uses one of your card rerolls; the shop sells more).

signal picked(card: int)
signal reroll_pressed

@onready var _title: Label = %LevelUpTitle
@onready var _cards: HBoxContainer = %Cards
@onready var _status: Label = %LevelUpStatus

const UNPICKED_MODULATE: Color = Color(0.45, 0.42, 0.5, 1.0)
const BADGE_COLOR: Color = Color(1.0, 0.85, 0.4)
const EVOLUTION_COLOR: Color = Color(0.6, 1.0, 0.6)

var _offered: Array[int] = []
var _pips: Array[LevelPips] = []
## The card's icon at the top of each card.
var _icons: Array[SpriteIcon] = []
## "New weapon!" / "New passive!" / "Evolution!" under the title.
var _badges: Array[Label] = []
var _reroll_button: Button = null
## The pressed-card look (gold border), reused to mark your pick.
var _picked_style: StyleBox = null
static var _screenshot_taken: bool = false
static var _picked_screenshot_taken: bool = false


## Shows these cards. `player` (this machine's, may be null) fills in each card's
## level and preview; `rerolls` is how many card rerolls they have left.
func open(level: int, offered: Array[int], player: Player = null, rerolls: int = 0) -> void:
	_offered = offered
	_title.text = "Level %d! Choose one" % level
	var stats := player.stats if player != null else null
	var buttons := _cards.get_children()
	for i: int in buttons.size():
		var button := buttons[i] as Button
		button.visible = i < offered.size()
		button.disabled = false
		button.modulate = Color.WHITE
		button.remove_theme_stylebox_override("disabled")
		if i >= offered.size():
			continue
		var card := offered[i]
		(button.get_node("Lines/Title") as Label).text = Cards.title(card, stats)
		(button.get_node("Lines/Description") as Label).text = Cards.description(card, player)
		_icons[i].sprite = Cards.icon(card, stats)
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
	Sfx.play(&"level_up", -4.0)
	if not offered.is_empty():
		(buttons[0] as Button).grab_focus()
	if not _screenshot_taken and not LaunchOptions.screenshot_dir.is_empty():
		_screenshot_taken = true
		await get_tree().process_frame
		set_status("Pick one!")
		Main.save_screenshot(get_tree(), "level_up.png")


func set_status(text: String) -> void:
	_status.text = text


func set_rerolls(rerolls: int) -> void:
	_reroll_button.text = "Reroll (%d left)" % rerolls if rerolls > 0 else "No rerolls (buy them in the shop)"
	_reroll_button.disabled = rerolls <= 0


## Your pick stays highlighted (gold border, others dimmed) while the rest of
## the team is still choosing.
func mark_picked(card: int) -> void:
	var index := _offered.find(card)
	var buttons := _cards.get_children()
	for i: int in buttons.size():
		var button := buttons[i] as Button
		button.disabled = true
		if i == index:
			button.add_theme_stylebox_override("disabled", _picked_style)
			button.modulate = Color.WHITE
		else:
			button.modulate = UNPICKED_MODULATE
	_reroll_button.disabled = true
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	if not _picked_screenshot_taken and not LaunchOptions.screenshot_dir.is_empty():
		_picked_screenshot_taken = true
		await get_tree().process_frame
		Main.save_screenshot(get_tree(), "level_up_picked.png")


func _ready() -> void:
	var buttons := _cards.get_children()
	_picked_style = (buttons[0] as Button).get_theme_stylebox("pressed")
	for i: int in buttons.size():
		var button := buttons[i] as Button
		button.pressed.connect(_on_card_pressed.bind(i))
		var lines := button.get_node("Lines")
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
		var icon := SpriteIcon.new("", Vector2(20, 20))
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


func _on_card_pressed(index: int) -> void:
	if index >= _offered.size():
		return
	picked.emit(_offered[index])
