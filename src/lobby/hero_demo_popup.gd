class_name HeroDemoPopup
extends Control
## The hero picker's Watch popup: the hero's name and class, a looping HeroDemo
## of their main weapon and ability (the caption of the part playing lights up),
## and Pick / Back buttons. Esc / B closes it.

signal picked(character_id: int)
signal closed

const DEMO_SIZE: Vector2 = Vector2(420, 170)
const NAME_COLOR: Color = Color(0.95, 0.78, 0.4)
const CLASS_COLOR: Color = Color(0.6, 0.57, 0.68)
const ACTIVE_COLOR: Color = Color(0.95, 0.93, 1.0)
const IDLE_COLOR: Color = Color(0.45, 0.42, 0.52)

var demo: HeroDemo = null
var _character_id: int = 0
var _name_label: Label = null
var _class_label: Label = null
var _weapon_label: Label = null
var _ability_label: Label = null
var _pick_button: Button = null
var _back_button: Button = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.04, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	_name_label = _label(18, NAME_COLOR)
	box.add_child(_name_label)
	_class_label = _label(9, CLASS_COLOR)
	box.add_child(_class_label)
	demo = HeroDemo.new()
	demo.custom_minimum_size = DEMO_SIZE
	demo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(demo)
	_weapon_label = _label(9, ACTIVE_COLOR)
	box.add_child(_weapon_label)
	_ability_label = _label(9, IDLE_COLOR)
	box.add_child(_ability_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	_pick_button = _button("")
	_pick_button.pressed.connect(func() -> void:
		close()
		picked.emit(_character_id))
	buttons.add_child(_pick_button)
	_back_button = _button("Back")
	_back_button.pressed.connect(close)
	buttons.add_child(_back_button)


## Shows `character_id`'s demo from the start, in the player's `color`.
func open(character_id: int, color: Color) -> void:
	_character_id = character_id
	var stats := Characters.get_character(character_id)
	_name_label.text = stats.hero_name
	_class_label.text = "the %s" % stats.display_name
	_weapon_label.text = "Main weapon - %s: %s" % [stats.main_weapon_name, Compendium.main_weapon_text(stats)]
	_ability_label.text = "Ability - %s: %s" % [stats.ability_name, stats.ability_description]
	_pick_button.text = "Pick %s" % stats.hero_name
	demo.color = color
	demo.character_id = character_id
	show()
	_pick_button.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _process(_delta: float) -> void:
	if not visible:
		return
	var ability := demo.part() == HeroDemo.Part.ABILITY
	_weapon_label.add_theme_color_override("font_color", IDLE_COLOR if ability else ACTIVE_COLOR)
	_ability_label.add_theme_color_override("font_color", ACTIVE_COLOR if ability else IDLE_COLOR)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(DEMO_SIZE.x, 0)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 24)
	button.add_theme_font_size_override("font_size", 9)
	return button
