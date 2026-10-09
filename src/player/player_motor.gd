class_name PlayerMotor
extends RefCounted
## Pure, deterministic player simulation: same state + same input = same result.
## The host runs it to decide what really happens. The owning client runs the
## exact same code to predict its own movement without waiting for the host.


## Advances `state` by one tick. Returns true if the main gun fires this tick.
static func step(state: PlayerState, input: PlayerInput, stats: CharacterStats, bounds: Rect2, delta: float) -> bool:
	state.aim = input.aim
	state.dash_cooldown_left = maxf(state.dash_cooldown_left - delta, 0.0)
	state.fire_cooldown_left = maxf(state.fire_cooldown_left - delta, 0.0)
	var move := input.move.limit_length(1.0)

	if input.dash_count != state.last_dash_count:
		state.last_dash_count = input.dash_count
		if state.dash_cooldown_left <= 0.0 and not state.is_dashing():
			# Dash where you're moving; if standing still, dash where you're aiming.
			if move.length_squared() > 0.0001:
				state.dash_direction = move.normalized()
			else:
				state.dash_direction = Vector2.from_angle(input.aim)
			state.dash_time_left = stats.dash_duration
			state.dash_cooldown_left = stats.dash_cooldown

	var velocity := move * stats.move_speed
	if state.is_dashing():
		velocity = state.dash_direction * stats.dash_speed
		state.dash_time_left = maxf(state.dash_time_left - delta, 0.0)
	state.position = clamp_to_bounds(state.position + velocity * delta, bounds, stats.body_radius)

	if input.fire and not state.is_dashing() and state.fire_cooldown_left <= 0.0:
		state.fire_cooldown_left = stats.fire_interval
		return true
	return false


static func clamp_to_bounds(point: Vector2, bounds: Rect2, radius: float) -> Vector2:
	var inner := bounds.grow(-radius)
	return point.clamp(inner.position, inner.end)
