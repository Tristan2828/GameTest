class_name LevelUpPanel
extends Control
## The level-up choice cards. Works with mouse (click) and gamepad/keyboard
## (focus moves between cards; confirm picks).

signal picked(upgrade_id: int)

@onready var _title: Label = %LevelUpTitle
@onready var _cards: HBoxContainer = %Cards
@onready var _status: Label = %LevelUpStatus

var _offered: Array[int] = []
static var _screenshot_taken: bool = false


## Shows the cards for these upgrade ids.
func open(level: int, offered: Array[int]) -> void:
	_offered = offered
	_title.text = "Level %d! Choose an upgrade" % level
	var buttons := _cards.get_children()
	for i: int in buttons.size():
		var button := buttons[i] as Button
		button.visible = i < offered.size()
		button.disabled = false
		if i < offered.size():
			var upgrade := Upgrades.get_upgrade(offered[i])
			(button.get_node("Lines/Title") as Label).text = upgrade.title
			(button.get_node("Lines/Description") as Label).text = upgrade.description
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


func _ready() -> void:
	var buttons := _cards.get_children()
	for i: int in buttons.size():
		(buttons[i] as Button).pressed.connect(_on_card_pressed.bind(i))


func _on_card_pressed(index: int) -> void:
	if index >= _offered.size():
		return
	for button: Node in _cards.get_children():
		(button as Button).disabled = true
	picked.emit(_offered[index])
