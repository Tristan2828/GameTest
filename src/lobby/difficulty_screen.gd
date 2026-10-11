class_name DifficultyScreen
extends RunConfigScreen
## Lobby page: difficulty sliders and Easy / Normal / Hard presets.
## The preset that matches the sliders is lit (gold border); when they match
## none, a "Custom" chip lights instead, a line spells out what differs from
## Normal, and those values turn gold with Normal's value beside them.
## Opening the page puts focus on the current preset (not always on Easy).

const CHANGED_COLOR: Color = Color(0.95, 0.78, 0.4)

var _preset_buttons: Dictionary[String, Button] = {}
var _custom_chip: Button = null


func _ready() -> void:
	set_title("Difficulty")


func open() -> void:
	super()
	var current := config.difficulty_name()
	if _preset_buttons.has(current) and editable:
		_preset_buttons[current].grab_focus()
	elif current == "Custom" and editable:
		var first := _first_slider()
		if first != null:
			first.grab_focus()


func _build_rows() -> void:
	_preset_buttons.clear()
	var presets := HBoxContainer.new()
	presets.alignment = BoxContainer.ALIGNMENT_CENTER
	presets.add_theme_constant_override("separation", 6)
	presets.add_child(label("Presets:", 9, NAME_COLOR))
	for preset_name: String in RunConfig.PRESETS:
		var button := Button.new()
		button.text = preset_name
		button.custom_minimum_size.x = 70
		button.toggle_mode = true
		button.disabled = not editable
		button.pressed.connect(func() -> void:
			config.apply_preset(preset_name)
			_changed())
		presets.add_child(button)
		_preset_buttons[preset_name] = button
	# Not a real button: it lights up when the sliders match no preset.
	_custom_chip = Button.new()
	_custom_chip.text = "Custom"
	_custom_chip.custom_minimum_size.x = 70
	_custom_chip.toggle_mode = true
	_custom_chip.focus_mode = Control.FOCUS_NONE
	_custom_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_custom_chip.tooltip_text = "Your own mix: move a slider and the settings become Custom"
	presets.add_child(_custom_chip)
	_refreshers.append(_refresh_presets)
	add_row(presets, false)
	var details := label("", 9, CHANGED_COLOR, true)
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_refreshers.append(func() -> void:
		var changed := config.difficulty_details()
		details.text = "Custom: %s (the rest as Normal)" % changed if config.difficulty_name() == "Custom" \
			else "%s: %s" % [config.difficulty_name(), config.difficulty_details(true)])
	add_row(details, false)
	_difficulty_slider("enemy_health", "Enemy health", "Regular enemies' HP", RunConfigScreen.percent)
	_difficulty_slider("boss_health", "Boss health", "Boss HP (still grows with players)", RunConfigScreen.percent)
	_difficulty_slider("enemy_count", "Enemy count", "How fast the horde spawns", RunConfigScreen.percent)
	_difficulty_slider("xp_rate", "XP gain", "Higher = level up more often", RunConfigScreen.percent)
	_difficulty_slider("coin_rate", "Coin drops", "Chance enemies drop coins", RunConfigScreen.percent)
	_difficulty_slider("hp_bonus", "Bonus HP", "Extra max HP for every hero", RunConfigScreen.signed)
	_changed_refresh_only()


## A slider whose value turns gold (with Normal's value beside it) when it
## differs from Normal.
func _difficulty_slider(key: String, title: String, hint: String, format: Callable) -> void:
	var slider := _slider(key, title, hint, format)
	var value_label := slider.get_parent().get_child(slider.get_index() + 1) as Label
	value_label.custom_minimum_size.x = VALUE_WIDTH + 56.0
	var normal_text: String = format.call(RunConfig.PRESETS["Normal"][key])
	_refreshers.append(func() -> void:
		var changed := config.differs_from_normal(key)
		value_label.text = "%s (Normal %s)" % [format.call(config.get(key)), normal_text] if changed else format.call(config.get(key))
		value_label.add_theme_color_override("font_color", CHANGED_COLOR if changed else TEXT_COLOR))


func _refresh_presets() -> void:
	var current := config.difficulty_name()
	for preset_name: String in _preset_buttons:
		_preset_buttons[preset_name].set_pressed_no_signal(preset_name == current)
	if _custom_chip != null:
		_custom_chip.set_pressed_no_signal(current == "Custom")
		_custom_chip.modulate = Color.WHITE if current == "Custom" else Color(1, 1, 1, 0.45)


func _first_slider() -> HSlider:
	for slider: Node in list.find_children("*", "HSlider", true, false):
		return slider as HSlider
	return null


## Fill in the preset label without telling the lobby anything changed.
func _changed_refresh_only() -> void:
	for refresh: Callable in _refreshers:
		refresh.call()
