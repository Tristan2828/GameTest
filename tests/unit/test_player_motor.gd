extends GutTest

const DELTA: float = 1.0 / 60.0
const BOUNDS: Rect2 = Rect2(0, 0, 960, 540)

var _stats: CharacterStats


func before_each() -> void:
	_stats = CharacterStats.new()


func _state_at(position: Vector2) -> PlayerState:
	var state := PlayerState.new()
	state.position = position
	return state


func _make_input(move: Vector2, fire: bool = false) -> PlayerInput:
	var input := PlayerInput.new()
	input.move = move
	input.fire = fire
	return input


func test_moves_at_move_speed() -> void:
	var state := _state_at(Vector2(100, 100))
	PlayerMotor.step(state, _make_input(Vector2.RIGHT), _stats, BOUNDS, DELTA)
	assert_almost_eq(state.position.x, 100.0 + _stats.move_speed * DELTA, 0.001)


func test_diagonal_is_not_faster() -> void:
	var state := _state_at(Vector2(100, 100))
	PlayerMotor.step(state, _make_input(Vector2(1, 1)), _stats, BOUNDS, DELTA)
	var distance := state.position.distance_to(Vector2(100, 100))
	assert_almost_eq(distance, _stats.move_speed * DELTA, 0.001)


func test_stays_inside_bounds() -> void:
	var state := _state_at(Vector2(2, 2))
	for i: int in 30:
		PlayerMotor.step(state, _make_input(Vector2(-1, -1)), _stats, BOUNDS, DELTA)
	assert_eq(state.position, Vector2(_stats.body_radius, _stats.body_radius))


func test_fire_rate_limited_by_interval() -> void:
	var state := _state_at(Vector2(100, 100))
	var shots := 0
	for i: int in 60:
		if PlayerMotor.step(state, _make_input(Vector2.ZERO, true), _stats, BOUNDS, DELTA) & PlayerMotor.FIRED:
			shots += 1
	var expected := ceili(1.0 / _stats.fire_interval)
	assert_between(shots, expected - 1, expected + 1)


func test_no_attack_without_a_target() -> void:
	var state := _state_at(Vector2(100, 100))
	for i: int in 30:
		assert_eq(PlayerMotor.step(state, _make_input(Vector2.RIGHT, false), _stats, BOUNDS, DELTA) & PlayerMotor.FIRED, 0)


func test_same_inputs_give_same_result() -> void:
	var a := _state_at(Vector2(300, 200))
	var b := _state_at(Vector2(300, 200))
	for i: int in 240:
		var input := _make_input(Vector2.from_angle(i * 0.1), i % 7 == 0)
		input.aim = i * 0.05
		var fired_a := PlayerMotor.step(a, input, _stats, BOUNDS, DELTA)
		var fired_b := PlayerMotor.step(b, input, _stats, BOUNDS, DELTA)
		assert_eq(fired_a, fired_b)
	assert_eq(a.position, b.position)
	assert_eq(a.fire_cooldown_left, b.fire_cooldown_left)
