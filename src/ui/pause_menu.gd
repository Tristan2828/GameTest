class_name PauseMenu
extends CanvasLayer
## Esc / Start during a session. Solo: the whole game pauses. Online: the game
## keeps running for everyone else, so only your own controls are blocked.

signal leave_requested

@onready var _resume_button: Button = %ResumeButton
@onready var _leave_button: Button = %LeaveButton
@onready var _hint_label: Label = %PauseHint


func _ready() -> void:
	# Keep working while the tree is paused (solo).
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_resume_button.pressed.connect(close)
	_leave_button.pressed.connect(func() -> void:
		close()
		leave_requested.emit())


func open() -> void:
	show()
	LocalInput.blocked = true
	if Net.is_online():
		_hint_label.text = "The game keeps going for everyone else while this is open."
	else:
		_hint_label.text = "Paused."
		get_tree().paused = true
	_resume_button.grab_focus()


func close() -> void:
	hide()
	LocalInput.blocked = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()
