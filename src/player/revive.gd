class_name Revive
extends RefCounted
## Co-op revives (pure rules; the host runs them, every peer draws the result).
##
## A player at 0 HP is *downed*: they lie where they fell inside a revive
## circle and can't move or attack. A teammate standing in the
## circle fills it; several helpers fill it faster. When it's full the downed
## player gets back up with half their HP. Nobody in the circle = it slowly
## drains. Being downed lasts until revived or the next stage (everyone respawns).

## Radius of the circle around a downed player.
const RADIUS: float = 30.0
## Seconds for one normal-speed helper to revive someone.
const SECONDS: float = 4.0
## How fast the circle drains when nobody is in it (fraction per second).
const DRAIN_PER_SECOND: float = 0.2
## Revived players come back with this share of their max HP (rounded up).
const HP_SHARE: float = 0.5
## Seconds a revived player can't be hit.
const INVULNERABILITY: float = 2.0
## The downed player's own camera stays on them this long, then shows a teammate.
const SPECTATE_DELAY: float = 1.5


## True if a helper standing at `helper_at` is inside the circle around `downed_at`.
static func in_range(downed_at: Vector2, helper_at: Vector2) -> bool:
	return downed_at.distance_squared_to(helper_at) <= RADIUS * RADIUS


## Progress after one tick. `helper_speed` is the sum of the revive_speed of
## everyone in the circle (0 = nobody).
static func step(progress: float, helper_speed: float, delta: float) -> float:
	if helper_speed > 0.0:
		return minf(progress + helper_speed * delta / SECONDS, 1.0)
	return maxf(progress - DRAIN_PER_SECOND * delta, 0.0)


## HP a revived player gets back (at least 1).
static func hp_after(max_hp: int) -> int:
	return clampi(ceili(max_hp * HP_SHARE), 1, maxi(max_hp, 1))
