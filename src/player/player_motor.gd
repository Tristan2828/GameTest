class_name PlayerMotor
extends RefCounted
## Pure, deterministic player simulation: same state + same input = same result.
## The host runs it to decide what really happens. The owning client runs the
## exact same code to predict its own movement without waiting for the host.

## Bits returned by step().
const FIRED: int = 1


## Advances `state` by one tick. Returns FIRED if the main weapon attacked.
static func step(state: PlayerState, input: PlayerInput, stats: CharacterStats, bounds: Rect2, delta: float) -> int:
	var result := 0
	state.aim = input.aim
	state.fire_cooldown_left = maxf(state.fire_cooldown_left - delta, 0.0)
	var move := input.move.limit_length(1.0)
	state.position = clamp_to_bounds(state.position + move * stats.move_speed * delta, bounds, stats.body_radius)
	if input.fire and state.fire_cooldown_left <= 0.0:
		state.fire_cooldown_left = stats.fire_interval
		result |= FIRED
	return result


static func clamp_to_bounds(point: Vector2, bounds: Rect2, radius: float) -> Vector2:
	var inner := bounds.grow(-radius)
	return point.clamp(inner.position, inner.end)
