class_name RunConfigScreen
extends ListScreen
## Base for the lobby's Difficulty and Custom Game pages: rows that edit one
## RunConfig value each (slider, on/off toggle, or a button that cycles through
## choices). The host edits; clients see the same rows read-only.

## A value changed (host only); the lobby saves and broadcasts the config.
signal config_changed

const LABEL_WIDTH: float = 130.0
const VALUE_WIDTH: float = 54.0

var config: RunConfig = RunConfig.new()
## False on clients: everything is shown but can't be changed.
var editable: bool = true
## Refreshes every row's value from `config` (filled as rows are built).
var _refreshers: Array[Callable] = []


func open() -> void:
	_build()
	super()


## Shows a new config (e.g. the host changed it) without rebuilding the rows.
func show_config(new_config: RunConfig) -> void:
	config = new_config
	for refresh: Callable in _refreshers:
		refresh.call()


## Subclasses add their rows here.
func _build_rows() -> void:
	pass


func _build() -> void:
	clear_list()
	_refreshers.clear()
	if not editable:
		add_heading("Only the host can change these.")
	_build_rows()


func _changed() -> void:
	for refresh: Callable in _refreshers:
		refresh.call()
	config_changed.emit()


## Name and hint on the left, the control in the middle, the value on the right.
func _setting_row(title: String, hint: String, control: Control, value_label: Label) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	var names := VBoxContainer.new()
	names.custom_minimum_size.x = LABEL_WIDTH
	names.add_theme_constant_override("separation", 1)
	names.add_child(label(title, 9, NAME_COLOR))
	if not hint.is_empty():
		var hint_label := label(hint, 9, DIM_COLOR, true)
		hint_label.custom_minimum_size.x = LABEL_WIDTH
		names.add_child(hint_label)
	line.add_child(names)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(control)
	if value_label != null:
		value_label.custom_minimum_size.x = VALUE_WIDTH
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(value_label)
	add_row(line, false)


## A slider for a numeric RunConfig value (limits from RunConfig.LIMITS).
func _slider(key: String, title: String, hint: String, format: Callable) -> HSlider:
	var limits: Array = RunConfig.LIMITS[key]
	var slider := HSlider.new()
	slider.min_value = limits[0]
	slider.max_value = limits[1]
	slider.step = limits[2]
	slider.editable = editable
	slider.custom_minimum_size.y = 12
	var value_label := label("", 9, TEXT_COLOR)
	var refresh := func() -> void:
		slider.set_value_no_signal(float(config.get(key)))
		value_label.text = format.call(config.get(key))
	slider.value_changed.connect(func(value: float) -> void:
		config.set_value(key, value)
		_changed())
	_refreshers.append(refresh)
	refresh.call()
	_setting_row(title, hint, slider, value_label)
	return slider


## An on/off toggle for a RunConfig flag.
func _toggle(key: String, title: String, hint: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.disabled = not editable
	toggle.focus_mode = Control.FOCUS_ALL
	var refresh := func() -> void:
		toggle.set_pressed_no_signal(bool(config.get(key)))
		toggle.text = "On" if config.get(key) else "Off"
	toggle.toggled.connect(func(on: bool) -> void:
		config.set(key, on)
		_changed())
	_refreshers.append(refresh)
	refresh.call()
	_setting_row(title, hint, toggle, null)
	return toggle


## A button that steps through `choices` (names); `get_index` / `set_index`
## read and write the config.
func _cycle(title: String, hint: String, choices: Array[String], get_index: Callable, set_index: Callable) -> Button:
	var button := Button.new()
	button.disabled = not editable
	button.focus_mode = Control.FOCUS_ALL
	var refresh := func() -> void:
		button.text = "<  %s  >" % choices[clampi(get_index.call(), 0, choices.size() - 1)]
	button.pressed.connect(func() -> void:
		set_index.call((int(get_index.call()) + 1) % choices.size())
		_changed())
	button.gui_input.connect(func(event: InputEvent) -> void:
		if not editable:
			return
		var step := 0
		if event.is_action_pressed("ui_left"):
			step = -1
		elif event.is_action_pressed("ui_right"):
			step = 1
		if step != 0:
			set_index.call(posmod(int(get_index.call()) + step, choices.size()))
			_changed()
			button.accept_event())
	_refreshers.append(refresh)
	refresh.call()
	_setting_row(title, hint, button, null)
	return button


static func percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


static func signed(value: int) -> String:
	return "%+d" % value if value != 0 else "0"


static func minutes(value: float) -> String:
	var whole := roundi(value)
	return "%d:%02d" % [whole / 60, whole % 60]
