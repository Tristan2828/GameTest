class_name AutoAim
extends RefCounted
## Where a hero's main weapon attacks. Nobody aims by hand (v0.22.0, owner
## decision: movement is the only control). Each weapon has its own rule:
## - Bolt Gun: the nearest enemy.
## - Reaper's Scythe: the way you face (your last movement direction).
## - Chain Lightning, Bone Spears: a random enemy nearby.
##
## Runs on the player's own computer from the enemies that screen shows; the
## result travels in PlayerInput like the old mouse aim, so the shooter's
## prediction and the host's attack always match. Pure: unit-testable.

## Reaper's Scythe only throws when an enemy is within this many times its reach.
const SCYTHE_WAKE_FACTOR: float = 1.5
## Lightning and spears look a little past their reach so they start early.
const RANDOM_REACH_MARGIN: float = 10.0


## The aim angle for `stats`' main weapon, or NAN when there's nothing worth
## attacking. `roll` (0..1) picks among enemies for the random weapons.
static func pick(stats: CharacterStats, from: Vector2, facing: float, enemies: PackedVector2Array, roll: float) -> float:
	var reach := reach_of(stats)
	match stats.main_weapon:
		CharacterStats.MainWeapon.SCYTHE:
			return facing if nearest(from, enemies, reach) != Vector2.INF else NAN
		CharacterStats.MainWeapon.LIGHTNING, CharacterStats.MainWeapon.SPEARS:
			var target := random_within(from, enemies, reach, roll)
			return (target - from).angle() if target != Vector2.INF else NAN
		_:
			var target := nearest(from, enemies, reach)
			return (target - from).angle() if target != Vector2.INF else NAN


## How far away an enemy can be for the weapon to go after it.
static func reach_of(stats: CharacterStats) -> float:
	match stats.main_weapon:
		CharacterStats.MainWeapon.SCYTHE:
			return stats.weapon_reach * SCYTHE_WAKE_FACTOR
		CharacterStats.MainWeapon.LIGHTNING:
			return stats.weapon_reach + RANDOM_REACH_MARGIN
		CharacterStats.MainWeapon.SPEARS:
			return MainWeapons.SPEAR_START + MainWeapons.SPEAR_SPACING * maxi(stats.projectile_count - 1, 0) \
				+ stats.weapon_radius + RANDOM_REACH_MARGIN
	return stats.bullet_speed * stats.bullet_lifetime


## The closest of `points` within `reach` of `from`, or Vector2.INF.
static func nearest(from: Vector2, points: PackedVector2Array, reach: float) -> Vector2:
	var best := Vector2.INF
	var best_distance := reach * reach
	for point: Vector2 in points:
		var distance := from.distance_squared_to(point)
		if distance <= best_distance:
			best = point
			best_distance = distance
	return best


## One of `points` within `reach` of `from`, picked by `roll` (0..1), or Vector2.INF.
static func random_within(from: Vector2, points: PackedVector2Array, reach: float, roll: float) -> Vector2:
	var inside := PackedVector2Array()
	for point: Vector2 in points:
		if from.distance_squared_to(point) <= reach * reach:
			inside.append(point)
	if inside.is_empty():
		return Vector2.INF
	return inside[clampi(floori(roll * inside.size()), 0, inside.size() - 1)]
