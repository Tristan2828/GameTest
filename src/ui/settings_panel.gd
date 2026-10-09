class_name SettingsPanel
extends PanelContainer
## Volume, fullscreen and screen shake. Used from the main menu and the pause
## menu. Changes apply immediately and are saved when the panel closes.

signal closed

@onready var _master: HSlider = %MasterSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _fullscreen: CheckButton = %FullscreenCheck
@onready var _shake: CheckButton = %ShakeCheck
@onready var _back: Button = %BackButton


func _ready() -> void:
	hide()
	_master.value_changed.connect(func(value: float) -> void:
		Settings.master_volume = value
		Settings.apply())
	_sfx.value_changed.connect(func(value: float) -> void:
		Settings.sfx_volume = value
		Settings.apply()
		Sfx.play(&"gem"))
	_fullscreen.toggled.connect(func(on: bool) -> void:
		Settings.fullscreen = on
		Settings.apply())
	_shake.toggled.connect(func(on: bool) -> void:
		Settings.screen_shake = on)
	_back.pressed.connect(close)


func open() -> void:
	_master.set_value_no_signal(Settings.master_volume)
	_sfx.set_value_no_signal(Settings.sfx_volume)
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	_shake.set_pressed_no_signal(Settings.screen_shake)
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
