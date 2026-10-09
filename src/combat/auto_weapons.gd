class_name AutoWeapons
extends RefCounted
## Registry of automatic weapons, plus the pure math every peer shares.
## The index in ALL is the network id: only add new weapons at the end.

enum Id { ORBITING_SKULLS, SEEKING_BOLTS, HOLY_AURA }

const MAX_LEVEL: int = 3
## Angle between bolts in a Seeking Bolts volley.
const SEEKER_SPREAD_DEGREES: float = 10.0

const ALL: Array[AutoWeapon] = [
	preload("res://src/combat/weapons/orbiting_skulls.tres"),
	preload("res://src/combat/weapons/seeking_bolts.tres"),
	preload("res://src/combat/weapons/holy_aura.tres"),
]


static func get_weapon(id: int) -> AutoWeapon:
	return ALL[clampi(id, 0, ALL.size() - 1)]


static func is_valid_id(id: int) -> bool:
	return id >= 0 and id < ALL.size()


## Where each orbiting skull is, from the player's position and the shared stage
## clock. Pure math, so every peer draws (and the host hits) the same spots.
static func orbit_positions(center: Vector2, level: int, clock: float) -> PackedVector2Array:
	var weapon := get_weapon(Id.ORBITING_SKULLS)
	var skulls := weapon.count_at(level)
	var result := PackedVector2Array()
	for i: int in skulls:
		var angle := clock * weapon.speed + TAU * i / skulls
		result.append(center + Vector2.from_angle(angle) * weapon.reach)
	return result


## Directions of a Seeking Bolts volley aimed at `aim`.
static func seeker_angles(level: int, aim: float) -> PackedFloat32Array:
	var bolts := get_weapon(Id.SEEKING_BOLTS).count_at(level)
	var result := PackedFloat32Array()
	for i: int in bolts:
		result.append(aim + deg_to_rad((i - (bolts - 1) / 2.0) * SEEKER_SPREAD_DEGREES))
	return result
