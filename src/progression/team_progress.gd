class_name TeamProgress
extends RefCounted
## The shared team XP bar and level. Owned by the host; clients get copies.

var level: int = 1
## XP collected toward the next level.
var xp: int = 0


static func xp_to_next(for_level: int) -> int:
	return 5 + (for_level - 1) * 5


## Adds XP and returns how many levels were gained (can be more than one).
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
	return gained


func progress_ratio() -> float:
	return float(xp) / float(xp_to_next(level))
