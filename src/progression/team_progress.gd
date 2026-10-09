class_name TeamProgress
extends RefCounted
## The shared team XP bar and level. Owned by the host; clients get copies.
##
## Pacing (v0.14.0, after the first co-op playtest had a level-up every ~8s):
## each level costs 14 more XP than the last, and the cost grows with the team
## size at the same rate as enemy spawns (+60% per extra player), so a team
## levels up about as often as a solo player does.

const BASE_XP: int = 16
const XP_PER_LEVEL: int = 14

var level: int = 1
## XP collected toward the next level.
var xp: int = 0
## Players in the game (host and clients both set it; the cost depends on it).
var player_count: int = 1


static func xp_to_next(for_level: int, players: int = 1) -> int:
	var base := BASE_XP + (for_level - 1) * XP_PER_LEVEL
	return roundi(base * (1.0 + SpawnDirector.EXTRA_PLAYER_MULTIPLIER * (maxi(players, 1) - 1)))


## Adds XP and returns how many levels were gained (can be more than one).
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next(level, player_count):
		xp -= xp_to_next(level, player_count)
		level += 1
		gained += 1
	return gained


func progress_ratio() -> float:
	return minf(float(xp) / float(xp_to_next(level, player_count)), 1.0)
