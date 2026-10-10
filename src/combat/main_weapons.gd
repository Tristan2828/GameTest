class_name MainWeapons
extends RefCounted
## Pure math for the heroes' aimed main weapons (Reaper's Scythe, Chain Lightning,
## Bone Spears), shared by every peer. The Bolt Gun uses ShotPatterns instead.
## WeaponSystem runs the weapons; the numbers live in each hero's CharacterStats.

## Angle between the scythes of one throw (Twin Scythes).
const SCYTHE_SPREAD_DEGREES: float = 25.0
## Bone Spears: the first spear rises this far ahead, the rest this far apart.
const SPEAR_START: float = 22.0
const SPEAR_SPACING: float = 22.0
## Seconds between neighbouring spears rising (the row runs outward).
const SPEAR_STAGGER: float = 0.04
## Splinters: bone shards from each spear.
const SHARD_SPEED: float = 220.0
const SHARD_LIFETIME: float = 0.35
const SHARD_DAMAGE_SHARE: float = 0.4
## Chain Lightning only picks a first target this close to the aim direction.
const LIGHTNING_CONE_DEGREES: float = 35.0
## How much a target off to the side counts as farther away (picks what you aim at).
const LIGHTNING_ANGLE_WEIGHT: float = 2.0
## Enemies this close are struck whichever way you aim (they're on top of you).
const LIGHTNING_POINT_BLANK: float = 14.0


## Directions of a scythe throw: `count` scythes fanned out around the aim.
static func scythe_angles(count: int, aim: float) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for i: int in count:
		result.append(aim + deg_to_rad((i - (count - 1) / 2.0) * SCYTHE_SPREAD_DEGREES))
	return result


## Where each spear of a row rises, nearest first.
static func spear_row(origin: Vector2, aim: float, count: int) -> PackedVector2Array:
	var direction := Vector2.from_angle(aim)
	var result := PackedVector2Array()
	for i: int in count:
		result.append((origin + direction * (SPEAR_START + SPEAR_SPACING * i)).round())
	return result


## Seconds of warning before spear `index` of a row strikes.
static func spear_warning(index: int, warning: float) -> float:
	return warning + index * SPEAR_STAGGER


## Splinters: directions of one spear's shards (the same on every peer).
static func shard_angles(seed_value: int, count: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var start := rng.randf() * TAU
	var result := PackedFloat32Array()
	for i: int in count:
		result.append(start + TAU * i / maxi(count, 1) + rng.randf_range(-0.3, 0.3))
	return result


static func shard_damage(spear_damage: int) -> int:
	return maxi(roundi(spear_damage * SHARD_DAMAGE_SHARE), 1)


## Damage of the strike that is jump number `jump` (0 = the first target).
static func chain_damage(base: int, growth: float, jump: int) -> int:
	return roundi(base * pow(1.0 + growth, jump))


## How good `target` is as Chain Lightning's first target from `from` aiming at
## `aim`: lower is better, -1 if it's out of reach or too far off the aim.
static func lightning_score(from: Vector2, aim: float, target: Vector2, reach: float) -> float:
	var offset := target - from
	var distance := offset.length()
	if distance > reach:
		return -1.0
	if distance <= LIGHTNING_POINT_BLANK:
		return distance
	var off_angle := absf(angle_difference(aim, offset.angle()))
	if off_angle > deg_to_rad(LIGHTNING_CONE_DEGREES):
		return -1.0
	return distance * (1.0 + LIGHTNING_ANGLE_WEIGHT * off_angle)
