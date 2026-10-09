class_name SettingsPanel
extends PanelContainer
## Volume, fullscreen, screen shake and the in-game cursor. Used from the main
## menu and the pause menu. Changes apply immediately and are saved when the
## panel closes.

signal closed

@onready var _master: HSlider = %MasterSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _music: HSlider = %MusicSlider
@onready var _fullscreen: CheckButton = %FullscreenCheck
@onready var _shake: CheckButton = %ShakeCheck
@onready var _back: Button = %BackButton
## Cursor rows (built in code): cycle buttons and a preview of the cursor.
var _cursor_buttons: Array[Button] = []
var _cursor_preview: TextureRect = null


func _ready() -> void:
	hide()
	_master.value_changed.connect(func(value: float) -> void:
		Settings.master_volume = value
		Settings.apply())
	_sfx.value_changed.connect(func(value: float) -> void:
		Settings.sfx_volume = value
		Settings.apply()
		Sfx.play(&"gem"))
	_music.value_changed.connect(func(value: float) -> void:
		Settings.music_volume = value
		Settings.apply())
	_fullscreen.toggled.connect(func(on: bool) -> void:
		Settings.fullscreen = on
		Settings.apply())
	_shake.toggled.connect(func(on: bool) -> void:
		Settings.screen_shake = on)
	_back.pressed.connect(close)
	_build_cursor_rows()


## "Cursor", "Cursor size" and "Cursor color": each a button that cycles its
## choices (click, or left / right on keyboard and gamepad).
func _build_cursor_rows() -> void:
	var box := _back.get_parent()
	var rows: Array[Array] = [
		["Cursor (in game)", GameCursor.STYLES, "cursor_style"],
		["Cursor size", GameCursor.SIZES, "cursor_size"],
		["Cursor color", GameCursor.COLOR_NAMES, "cursor_color"],
	]
	for row_info: Array in rows:
		var row := HBoxContainer.new()
		var title := Label.new()
		title.text = row_info[0]
		title.custom_minimum_size.x = 90
		title.add_theme_font_size_override("font_size", 9)
		row.add_child(title)
		var button := Button.new()
		button.custom_minimum_size.x = 130
		button.add_theme_font_size_override("font_size", 9)
		var choices: Array[String] = row_info[1]
		var key: String = row_info[2]
		button.pressed.connect(_step_cursor.bind(key, choices.size(), 1))
		button.gui_input.connect(func(event: InputEvent) -> void:
			var step := 0
			if event.is_action_pressed("ui_left"):
				step = -1
			elif event.is_action_pressed("ui_right"):
				step = 1
			if step != 0:
				_step_cursor(key, choices.size(), step)
				button.accept_event())
		button.set_meta(&"choices", choices)
		button.set_meta(&"key", key)
		row.add_child(button)
		box.add_child(row)
		box.move_child(row, _back.get_index())
		_cursor_buttons.append(button)
	_cursor_preview = TextureRect.new()
	_cursor_preview.custom_minimum_size = Vector2(0, 22)
	_cursor_preview.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_cursor_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(_cursor_preview)
	box.move_child(_cursor_preview, _back.get_index())
	_refresh_cursor_rows()


func _step_cursor(key: String, count: int, step: int) -> void:
	Settings.set(key, posmod(int(Settings.get(key)) + step, count))
	Settings.apply()
	_refresh_cursor_rows()


func _refresh_cursor_rows() -> void:
	for button: Button in _cursor_buttons:
		var choices: Array[String] = button.get_meta(&"choices")
		var key: String = button.get_meta(&"key")
		button.text = "<  %s  >" % choices[clampi(int(Settings.get(key)), 0, choices.size() - 1)]
	# Preview at game scale (the real cursor is scaled to the window).
	var size_scale := 1 if Settings.cursor_size <= 1 else Settings.cursor_size
	_cursor_preview.texture = null if Settings.cursor_style <= 0 else 		ImageTexture.create_from_image(GameCursor.build_image(Settings.cursor_style, Settings.cursor_color, size_scale))


func open() -> void:
	_master.set_value_no_signal(Settings.master_volume)
	_sfx.set_value_no_signal(Settings.sfx_volume)
	_music.set_value_no_signal(Settings.music_volume)
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	_shake.set_pressed_no_signal(Settings.screen_shake)
	_refresh_cursor_rows()
	show()
	_master.grab_focus()


func close() -> void:
	Settings.save()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
