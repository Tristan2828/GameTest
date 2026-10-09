class_name LevelUpPanel
extends Control
## The level-up choice cards. Works with mouse (click) and gamepad/keyboard
## (focus moves between cards; confirm picks). After you pick, your card stays
## lit with a gold border while the others dim, until everyone has chosen.

signal picked(upgrade_id: int)

@onready var _title: Label = %LevelUpTitle
@onready var _cards: HBoxContainer = %Cards
@onready var _status: Label = %LevelUpStatus

const UNPICKED_MODULATE: Color = Color(0.45, 0.42, 0.5, 1.0)

var _offered: Array[int] = []
var _pips: Array[LevelPips] = []
## The pressed-card look (gold border), reused to mark your pick.
var _picked_style: StyleBox = null
static var _screenshot_taken: bool = false
static var _picked_screenshot_taken: bool = false


## Shows the cards for these upgrade ids. `player` (this machine's, may be null)
## fills in each card's level and stat preview.
func open(level: int, offered: Array[int], player: Player = null) -> void:
	_offered = offered
	_title.text = "Level %d! Choose an upgrade" % level
	var buttons := _cards.get_children()
	for i: int in buttons.size():
		var button := buttons[i] as Button
		button.visible = i < offered.size()
		button.disabled = false
		button.modulate = Color.WHITE
		button.remove_theme_stylebox_override("disabled")
		if i < offered.size():
			var upgrade := Upgrades.get_upgrade(offered[i])
			(button.get_node("Lines/Title") as Label).text = upgrade.title
			(button.get_node("Lines/Description") as Label).text = upgrade.description
			var level_label := button.get_node("Lines/Level") as Label
			var preview_label := button.get_node("Lines/Preview") as Label
			level_label.text = ""
			preview_label.text = ""
			_pips[i].visible = false
			if player != null:
				level_label.text = Upgrades.level_text(offered[i], player.upgrade_ids)
				preview_label.text = Upgrades.preview_text(offered[i], player.stats, player.health)
				if upgrade.stat != Upgrade.Stat.HEAL:
					_pips[i].owned = Upgrades.stacks_owned(offered[i], player.upgrade_ids)
					_pips[i].maximum = upgrade.max_stacks
					_pips[i].visible = true
			# The pips replace the "Lv 2 -> 3 of 5" line when we know the player.
			level_label.visible = not level_label.text.is_empty() and not _pips[i].visible
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


## Your pick stays highlighted (gold border, others dimmed) while the rest of
## the team is still choosing.
func mark_picked(upgrade_id: int) -> void:
	var index := _offered.find(upgrade_id)
	var buttons := _cards.get_children()
	for i: int in buttons.size():
		var button := buttons[i] as Button
		button.disabled = true
		if i == index:
			button.add_theme_stylebox_override("disabled", _picked_style)
			button.modulate = Color.WHITE
		else:
			button.modulate = UNPICKED_MODULATE
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
		var pips := LevelPips.new()
		pips.visible = false
		var lines := button.get_node("Lines")
		lines.add_child(pips)
		lines.move_child(pips, 1)  # Right under the title.
		_pips.append(pips)


func _on_card_pressed(index: int) -> void:
	if index >= _offered.size():
		return
	picked.emit(_offered[index])
