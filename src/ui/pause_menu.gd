class_name PauseMenu
extends CanvasLayer
## Esc / Start during a session. Solo and the online host: the game pauses (the
## host's pause freezes it for everyone, and closing the menu starts a "3, 2, 1").
## A client's menu doesn't pause: only their own controls are blocked.

signal leave_requested
## Solo / host: the menu opened (true) or closed (false). Main tells the arena.
signal pause_changed(paused: bool)
## "Send feedback" was pressed (Main hides this menu, takes a screenshot, opens the screen).
signal feedback_requested

@onready var _resume_button: Button = %ResumeButton
@onready var _leave_button: Button = %LeaveButton
@onready var _hint_label: Label = %PauseHint
@onready var _settings_button: Button = %SettingsButton
@onready var _box: Control = $Center/Box
@onready var _settings: SettingsPanel = %Settings
@onready var _feedback_button: Button = %FeedbackButton
## This menu paused the game (solo / host) and has to unpause it when closed.
var _pausing: bool = false


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
	if Net.is_online() and not multiplayer.is_server():
		_hint_label.text = "The game keeps going for everyone else while this is open."
	else:
		_hint_label.text = "Paused for everyone. Play resumes after a 3, 2, 1." if Net.is_online() else "Paused."
		if not Net.is_online():
			get_tree().paused = true
		_pausing = true
		pause_changed.emit(true)
	_resume_button.grab_focus()


## Back from the feedback screen (still paused / input still blocked).
func show_after_feedback() -> void:
	show()
	_feedback_button.grab_focus()


func close() -> void:
	hide()
	LocalInput.blocked = false
	get_tree().paused = false
	if _pausing:
		_pausing = false
		pause_changed.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if visible and not _settings.visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()
