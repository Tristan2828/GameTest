class_name PlayerMotor
extends RefCounted
## Pure, deterministic player simulation: same state + same input = same result.
## The host runs it to decide what really happens. The owning client runs the
## exact same code to predict its own movement without waiting for the host.
## Movement abilities (Dash, Blink) happen here so they're predicted too.

## Bits returned by step().
const FIRED: int = 1
const ABILITY_USED: int = 2


## Advances `state` by one tick. Returns FIRED / ABILITY_USED bits for what happened.
static func step(state: PlayerState, input: PlayerInput, stats: CharacterStats, bounds: Rect2, delta: float) -> int:
	var result := 0
	state.aim = input.aim
	state.ability_cooldown_left = maxf(state.ability_cooldown_left - delta, 0.0)
	state.fire_cooldown_left = maxf(state.fire_cooldown_left - delta, 0.0)
	var move := input.move.limit_length(1.0)

	if input.ability_count != state.last_ability_count:
		state.last_ability_count = input.ability_count
		if state.ability_cooldown_left <= 0.0 and not state.is_dashing():
			result |= ABILITY_USED
			state.ability_cooldown_left = stats.ability_cooldown
			# Go where you're moving; if standing still, where you're aiming.
			var direction := move.normalized() if move.length_squared() > 0.0001 else Vector2.from_angle(input.aim)
			match stats.ability:
				CharacterStats.Ability.DASH:
					state.dash_direction = direction
					state.dash_time_left = stats.dash_duration * stats.ability_power
				CharacterStats.Ability.BLINK:
					var target := state.position + direction * stats.blink_distance * stats.ability_power
					state.position = clamp_to_bounds(target, bounds, stats.body_radius)
				_:
					pass  # Grave Blast: the host resolves the blast itself.

	var velocity := move * stats.move_speed
	if state.is_dashing():
		velocity = state.dash_direction * stats.dash_speed
		state.dash_time_left = maxf(state.dash_time_left - delta, 0.0)
	state.position = clamp_to_bounds(state.position + velocity * delta, bounds, stats.body_radius)

	if input.fire and not state.is_dashing() and state.fire_cooldown_left <= 0.0:
		state.fire_cooldown_left = stats.fire_interval
		result |= FIRED
	return result


static func clamp_to_bounds(point: Vector2, bounds: Rect2, radius: float) -> Vector2:
	var inner := bounds.grow(-radius)
	return point.clamp(inner.position, inner.end)
