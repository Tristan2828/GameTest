extends Node
## Registers every input action in code instead of the editor's Input Map, so all
## bindings live in one readable, text-editable place. Each action is bound to
## both keyboard and gamepad. In a run you only move: weapons fire by themselves.

const STICK_DEADZONE: float = 0.2


func _enter_tree() -> void:
	_add_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add_action("move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add_action("move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	# Godot's built-in "confirm" for menus has no gamepad button by default, so
	# controllers could move between buttons but not press them.
	_add_action("ui_accept", [_joy(JOY_BUTTON_A)])
	_add_action("copy_invite", [_key(KEY_F1)])
	_add_action("restart", [_key(KEY_R), _joy(JOY_BUTTON_BACK)])
	_add_action("pause", [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)])
	# While you're downed: watch the next teammate.
	_add_action("switch_view", [
		_key(KEY_SPACE),
		_key(KEY_ENTER),
		_mouse(MOUSE_BUTTON_LEFT),
		_joy(JOY_BUTTON_A),
		_joy(JOY_BUTTON_RIGHT_SHOULDER),
	])


func _add_action(action: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, STICK_DEADZONE)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


func _key(physical_key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical_key
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


func _joy(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func _axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	return event
