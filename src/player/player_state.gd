class_name PlayerState
extends RefCounted
## Everything the player simulation remembers between ticks.

var position: Vector2 = Vector2.ZERO
var aim: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var dash_time_left: float = 0.0
var ability_cooldown_left: float = 0.0
var last_ability_count: int = 0
var fire_cooldown_left: float = 0.0


func is_dashing() -> bool:
	return dash_time_left > 0.0
