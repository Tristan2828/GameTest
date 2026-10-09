class_name PlayerHealth
extends RefCounted
## Hearts and post-hit invulnerability. The host owns this; clients receive copies
## through snapshots.

var max_hearts: int = 3
var hearts: int = 3
var invulnerable_left: float = 0.0


func reset(max_value: int) -> void:
	max_hearts = max_value
	hearts = max_value
	invulnerable_left = 0.0


func is_downed() -> bool:
	return hearts <= 0


func is_invulnerable() -> bool:
	return invulnerable_left > 0.0


func tick(delta: float) -> void:
	invulnerable_left = maxf(invulnerable_left - delta, 0.0)


## Returns true if the hit landed (not downed and not invulnerable).
func take_hit(amount: int, invulnerability_seconds: float) -> bool:
	if is_downed() or is_invulnerable():
		return false
	hearts = maxi(hearts - amount, 0)
	invulnerable_left = invulnerability_seconds
	return true


func heal(amount: int) -> void:
	if is_downed():
		return
	hearts = mini(hearts + amount, max_hearts)
