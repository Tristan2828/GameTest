class_name AutoWeapon
extends Resource
## An automatic weapon (found on altars during stages). Each is a `.tres` file in
## `src/combat/weapons/`, registered in AutoWeapons.ALL (index = network id).
## Numbers grow with the weapon's level (1..AutoWeapons.MAX_LEVEL).

## Sent as numbers in .tres files: only add new kinds at the end.
enum Kind { ORBIT, SEEKER, AURA, CHAIN, BOOMERANG, TRAIL, ERUPTION }

@export var title: String = "Weapon"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.ORBIT
@export var color: Color = Color.WHITE
## PixelArt sprite shown in the HUD, the run summary and on altars.
@export var icon: String = ""

@export var damage: int = 8
@export var damage_per_level: int = 0
## Orbit: skulls. Seeker: bolts per volley. Chain: jumps after the first hit.
## Boomerang: scythes per throw. Eruption: spears per volley.
@export var count: int = 1
@export var count_per_level: int = 0
## Seconds between volleys/pulses (Orbit: per-enemy hit cooldown; Trail: burn tick).
@export var interval: float = 1.0
## Each level multiplies the interval by this (0.8 = 20% faster per level).
@export var interval_scale_per_level: float = 1.0
## Orbit: skull size. Aura, Trail, Eruption: damage radius. Boomerang: hit size.
## Chain: how far the lightning jumps to the next enemy.
@export var radius: float = 4.0
@export var radius_per_level: float = 0.0
## Orbit: radians per second. Seeker: bolt speed in px/s.
@export var speed: float = 3.0
## Orbit: distance from the player. Seeker, Chain, Eruption: targeting range.
## Boomerang: how far the scythe flies out.
@export var reach: float = 28.0
## Boomerang: seconds out and back. Trail: how long a flame burns.
## Eruption: warning before the spear strikes.
@export var duration: float = 1.0


func damage_at(level: int) -> int:
	return damage + damage_per_level * (level - 1)


func count_at(level: int) -> int:
	return count + count_per_level * (level - 1)


func interval_at(level: int) -> float:
	return interval * pow(interval_scale_per_level, level - 1)


func radius_at(level: int) -> float:
	return radius + radius_per_level * (level - 1)
