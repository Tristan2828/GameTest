class_name AutoWeapon
extends Resource
## An automatic weapon (found on altars during stages). Each is a `.tres` file in
## `src/combat/weapons/`, registered in AutoWeapons.ALL (index = network id).
## Numbers grow with the weapon's level (1..AutoWeapons.MAX_LEVEL).

enum Kind { ORBIT, SEEKER, AURA }

@export var title: String = "Weapon"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.ORBIT
@export var color: Color = Color.WHITE

@export var damage: int = 8
@export var damage_per_level: int = 0
## Orbit: skulls. Seeker: bolts per volley.
@export var count: int = 1
@export var count_per_level: int = 0
## Seconds between volleys/pulses (Orbit: per-enemy hit cooldown).
@export var interval: float = 1.0
## Each level multiplies the interval by this (0.8 = 20% faster per level).
@export var interval_scale_per_level: float = 1.0
## Orbit: skull size. Aura: damage radius.
@export var radius: float = 4.0
@export var radius_per_level: float = 0.0
## Orbit: radians per second. Seeker: bolt speed in px/s.
@export var speed: float = 3.0
## Orbit: distance from the player. Seeker: targeting range.
@export var reach: float = 28.0


func damage_at(level: int) -> int:
	return damage + damage_per_level * (level - 1)


func count_at(level: int) -> int:
	return count + count_per_level * (level - 1)


func interval_at(level: int) -> float:
	return interval * pow(interval_scale_per_level, level - 1)


func radius_at(level: int) -> float:
	return radius + radius_per_level * (level - 1)
