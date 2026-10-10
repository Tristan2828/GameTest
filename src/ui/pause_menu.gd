class_name PauseMenu
extends CanvasLayer
## Esc / Start during a session. Solo: the whole game pauses. Online: the game
## keeps running for everyone (host included), so only your own controls are
## blocked. (v0.17.0's host pause that froze everyone was removed in v0.18.0.)

signal leave_requested
## "Send feedback" was pressed (Main hides this menu, takes a screenshot, opens the screen).
signal feedback_requested

@onready var _resume_button: Button = %ResumeButton
@onready var _leave_button: Button = %LeaveButton
@onready var _hint_label: Label = %PauseHint
@onready var _settings_button: Button = %SettingsButton
@onready var _box: Control = $Center/Box
@onready var _settings: SettingsPanel = %Settings
@onready var _feedback_button: Button = %FeedbackButton


func _ready() -> void:
	# Keep working while the tree is paused (solo).
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_resume_button.pressed.connect(close)
	_settings_button.pressed.connect(func() -> void:
		_box.hide()
		_settings.open())
	_settings.closed.connect(func() -> void:
		_box.show()
		_settings_button.grab_focus())
	_feedback_button.pressed.connect(func() -> void: feedback_requested.emit())
	_leave_button.pressed.connect(func() -> void:
		close()
		leave_requested.emit())


func open() -> void:
	show()
	_box.show()
	_settings.hide()
	LocalInput.blocked = true
	if Net.is_online():
		_hint_label.text = "The game keeps going for everyone else while this is open."
	else:
		_hint_label.text = "Paused."
		get_tree().paused = true
	_resume_button.grab_focus()


## Back from the feedback screen (still paused / input still blocked).
func show_after_feedback() -> void:
	show()
	_feedback_button.grab_focus()


func close() -> void:
	hide()
	LocalInput.blocked = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and not _settings.visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()
