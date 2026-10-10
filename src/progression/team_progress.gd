class_name TeamProgress
extends RefCounted
## The shared team XP bar and level. Owned by the host; clients get copies.
##
## Pacing: v0.12 had a level-up every ~8s in co-op (too many pauses); v0.14.0
## made levels so expensive that the team was too weak to clear stage 1.
## v0.15.0 sits in between: each level costs 9 more XP than the last, and the
## cost grows by 40% per extra player (spawns grow 60%), so a bigger team still
## levels a little faster than a solo player.
## v0.18.0: past level 15 (about the end of stage 1) levels also get a growing
## extra cost, so teams don't snowball through stages 2-3 with 50+ upgrades.

const BASE_XP: int = 10
const XP_PER_LEVEL: int = 9
## Extra XP cost per player beyond the first.
const TEAM_COST_PER_EXTRA_PLAYER: float = 0.4
## From this level on, each level costs LATE_XP_SQUARED * (levels past it)^2 more.
const LATE_LEVEL: int = 15
const LATE_XP_SQUARED: float = 1.5

var level: int = 1
## XP collected toward the next level.
var xp: int = 0
## Players in the game (host and clients both set it; the cost depends on it).
var player_count: int = 1
## Difficulty "XP gain": the cost of every level is divided by this.
var xp_rate: float = 1.0


static func xp_to_next(for_level: int, players: int = 1, rate: float = 1.0) -> int:
	var base := BASE_XP + (for_level - 1) * XP_PER_LEVEL + LATE_XP_SQUARED * pow(maxi(for_level - LATE_LEVEL, 0), 2.0)
	var team := 1.0 + TEAM_COST_PER_EXTRA_PLAYER * (maxi(players, 1) - 1)
	return maxi(roundi(base * team / maxf(rate, 0.01)), 1)


## Adds XP and returns how many levels were gained (can be more than one).
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next(level, player_count, xp_rate):
		xp -= xp_to_next(level, player_count, xp_rate)
		level += 1
		gained += 1
	return gained


func progress_ratio() -> float:
	return minf(float(xp) / float(xp_to_next(level, player_count, xp_rate)), 1.0)
