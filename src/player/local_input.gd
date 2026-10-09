class_name LocalInput
extends Node
## Reads this computer's mouse/keyboard or gamepad and turns it into PlayerInput.
## Aiming follows whichever device moved last: the mouse, or the right stick.
## Gamepad players also auto-fire while the right stick is pushed far enough.

const AIM_STICK_DEADZONE: float = 0.35
const STICK_AUTOFIRE_THRESHOLD: float = 0.6
const AUTOPILOT_DASH_INTERVAL: float = 2.0

var _using_mouse: bool = true
var _last_stick_aim: float = 0.0
var _dash_count: int = 0
var _autopilot_time: float = 0.0


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_using_mouse = true


## Call once per physics tick.
func sample(player: Player, delta: float) -> PlayerInput:
	if LaunchOptions.autopilot:
		return _sample_autopilot(player, delta)

	var input := PlayerInput.new()
	input.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > AIM_STICK_DEADZONE:
		_using_mouse = false
		_last_stick_aim = stick.angle()

	if _using_mouse:
		input.aim = (player.get_global_mouse_position() - player.global_position).angle()
	else:
		input.aim = _last_stick_aim

	var stick_autofire := not _using_mouse and stick.length() > STICK_AUTOFIRE_THRESHOLD
	input.fire = Input.is_action_pressed("fire") or stick_autofire

	if Input.is_action_just_pressed("dash"):
		_dash_count += 1
	input.dash_count = _dash_count
	return input


## Test mode (`--autopilot`): kite away from the nearest enemy while shooting it,
## drift in a circle, and dash regularly.
func _sample_autopilot(player: Player, delta: float) -> PlayerInput:
	_autopilot_time += delta
	var input := PlayerInput.new()
	input.move = Vector2.from_angle(_autopilot_time * 0.7) * 0.5
	input.dash_count = int(_autopilot_time / AUTOPILOT_DASH_INTERVAL)

	var nearest: Enemy = null
	var nearest_distance := INF
	for node: Node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.active:
			continue
		var distance := enemy.global_position.distance_squared_to(player.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	if nearest != null:
		var to_enemy := nearest.global_position - player.global_position
		input.aim = to_enemy.angle()
		input.fire = true
		if to_enemy.length() < 120.0:
			input.move = (input.move - to_enemy.normalized()).limit_length(1.0)
	return input
