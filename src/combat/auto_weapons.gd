class_name AutoWeapons
extends RefCounted
## Registry of automatic weapons, plus the pure math every peer shares.
## The index in ALL is the network id: only add new weapons at the end.

## CHAIN_LIGHTNING, REAPERS_SCYTHE and BONE_SPEARS keep their old names here, but
## they're Storm Lantern, Bone Cleaver and Grave Spikes in the game (v0.23.0):
## the heroes' main weapons with those names live in MainWeapons.
enum Id {
	ORBITING_SKULLS, SEEKING_BOLTS, HOLY_AURA, CHAIN_LIGHTNING, REAPERS_SCYTHE, HELLFIRE_TRAIL, BONE_SPEARS,
	GRAVE_BLAST, HEX_SNARE, BONE_EFFIGY, SPIRIT_DAGGERS, DEATH_SPIRAL, SOUL_BARRAGE, SANCTUARY, INFERNO_PATH,
}

## Levels a weapon can reach (evolutions have one; AutoWeapon.max_level()).
const MAX_LEVEL: int = 5
## Weapons offered on level-up cards, altars and chests. Grave Blast, Hex Snare
## and Bone Effigy were heroes' abilities until v0.22.0.
const PICKUPS: Array[int] = [
	Id.ORBITING_SKULLS, Id.SEEKING_BOLTS, Id.HOLY_AURA, Id.HELLFIRE_TRAIL, Id.GRAVE_BLAST, Id.HEX_SNARE, Id.BONE_EFFIGY,
	Id.CHAIN_LIGHTNING, Id.REAPERS_SCYTHE, Id.BONE_SPEARS, Id.SPIRIT_DAGGERS,
]
## Evolved weapons (each names its base weapon and the passive it needs).
const EVOLUTIONS: Array[int] = [Id.DEATH_SPIRAL, Id.SOUL_BARRAGE, Id.SANCTUARY, Id.INFERNO_PATH]
## Weapon slots per player, the hero's main weapon included.
const WEAPON_SLOTS: int = 6
## Grave Blast heals this share of your max HP.
const BLAST_HEAL_SHARE: float = 0.1
## Hex Snare: hexed enemies take this much damage (1.5 = +50%).
const HEX_DAMAGE_MULTIPLIER: float = 1.5
## Bone Effigy rises this far from you, toward the crowd.
const EFFIGY_DISTANCE: float = 40.0
## Grave Blast goes off once an enemy is this close (times its damage radius).
const BLAST_WAKE_FACTOR: float = 1.2
## Enemies within this distance of each other count as one crowd.
const CROWD_RADIUS: float = 40.0
## Angle between bolts in a Seeking Bolts volley.
const SEEKER_SPREAD_DEGREES: float = 10.0

const ALL: Array[AutoWeapon] = [
	preload("res://src/combat/weapons/orbiting_skulls.tres"),
	preload("res://src/combat/weapons/seeking_bolts.tres"),
	preload("res://src/combat/weapons/holy_aura.tres"),
	preload("res://src/combat/weapons/chain_lightning.tres"),
	preload("res://src/combat/weapons/reapers_scythe.tres"),
	preload("res://src/combat/weapons/hellfire_trail.tres"),
	preload("res://src/combat/weapons/bone_spears.tres"),
	preload("res://src/combat/weapons/grave_blast.tres"),
	preload("res://src/combat/weapons/hex_snare.tres"),
	preload("res://src/combat/weapons/bone_effigy.tres"),
	preload("res://src/combat/weapons/spirit_daggers.tres"),
	preload("res://src/combat/weapons/death_spiral.tres"),
	preload("res://src/combat/weapons/soul_barrage.tres"),
	preload("res://src/combat/weapons/sanctuary.tres"),
	preload("res://src/combat/weapons/inferno_path.tres"),
]


static func get_weapon(id: int) -> AutoWeapon:
	return ALL[clampi(id, 0, ALL.size() - 1)]


static func is_valid_id(id: int) -> bool:
	return id >= 0 and id < ALL.size()


## The evolved weapon that `weapon_id` becomes, or -1 if it has none.
static func evolution_of(weapon_id: int) -> int:
	for evolved: int in EVOLUTIONS:
		if ALL[evolved].evolves_from == weapon_id:
			return evolved
	return -1


## The middle of the biggest crowd among `points` within `reach` of `from`: the
## enemy with the most others within CROWD_RADIUS, nudged to the average of that
## group. Vector2.INF if nobody is in reach. Hex Snare and Bone Effigy aim here.
static func crowd_center(from: Vector2, points: PackedVector2Array, reach: float) -> Vector2:
	var inside := PackedVector2Array()
	for point: Vector2 in points:
		if from.distance_squared_to(point) <= reach * reach:
			inside.append(point)
	var best := Vector2.INF
	var best_count := 0
	for point: Vector2 in inside:
		var sum := Vector2.ZERO
		var count := 0
		for other: Vector2 in inside:
			if point.distance_squared_to(other) <= CROWD_RADIUS * CROWD_RADIUS:
				sum += other
				count += 1
		if count > best_count:
			best_count = count
			best = sum / count
	return best


## Where each orbiting skull is (Orbiting Skulls or Death Spiral, `weapon_id`),
## from the player's position and the shared stage clock. Pure math, so every
## peer draws (and the host hits) the same spots.
static func orbit_positions(center: Vector2, level: int, clock: float,
		weapon_id: int = Id.ORBITING_SKULLS) -> PackedVector2Array:
	var weapon := get_weapon(weapon_id)
	var skulls := weapon.count_at(level)
	var result := PackedVector2Array()
	for i: int in skulls:
		var angle := clock * weapon.speed + TAU * i / skulls
		result.append(center + Vector2.from_angle(angle) * weapon.reach)
	return result


## Directions of a Seeking Bolts (or Spirit Daggers, Soul Barrage) volley aimed at `aim`.
static func seeker_angles(level: int, aim: float, weapon_id: int = Id.SEEKING_BOLTS) -> PackedFloat32Array:
	var bolts := get_weapon(weapon_id).count_at(level)
	var result := PackedFloat32Array()
	for i: int in bolts:
		result.append(aim + deg_to_rad((i - (bolts - 1) / 2.0) * SEEKER_SPREAD_DEGREES))
	return result


## Where a Reaper's Scythe is, `progress` (0..1) through its flight: it flies
## out from its thrower along `angle`, slows, and comes back to them.
static func scythe_position(thrower: Vector2, angle: float, reach: float, progress: float) -> Vector2:
	return thrower + Vector2.from_angle(angle) * reach * sin(PI * clampf(progress, 0.0, 1.0))


## Directions of a scythe throw: `count` scythes spread evenly around the aim.
static func scythe_angles(count: int, aim: float) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for i: int in count:
		result.append(aim + TAU * i / maxi(count, 1))
	return result
