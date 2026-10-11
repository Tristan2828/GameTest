class_name AutoWeapon
extends Resource
## An automatic weapon (offered on level-up cards, found on altars and in chests).
## Each is a `.tres` file in `src/combat/weapons/`, registered in AutoWeapons.ALL
## (index = network id). Numbers grow with the weapon's level (1..max_level()).
## Evolved weapons (`evolves_from` set) replace their base weapon and have one level.

## Sent as numbers in .tres files: only add new kinds at the end.
## BLAST, HEX and EFFIGY were the heroes' button abilities until v0.22.0.
## DAGGERS (v0.23.0): bolts thrown the way you last moved, and behind you.
enum Kind { ORBIT, SEEKER, AURA, CHAIN, BOOMERANG, TRAIL, ERUPTION, BLAST, HEX, EFFIGY, DAGGERS }

@export var title: String = "Weapon"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.ORBIT
@export var color: Color = Color.WHITE
## PixelArt sprite shown in the HUD, the run summary and on altars.
@export var icon: String = ""

@export var damage: int = 8
@export var damage_per_level: int = 0
## Orbit: skulls. Seeker, Daggers: bolts per volley. Chain: jumps after the first hit.
## Boomerang: scythes per throw. Eruption: spears per volley.
@export var count: int = 1
@export var count_per_level: int = 0
## Seconds between volleys/pulses (Orbit: per-enemy hit cooldown; Trail: burn tick).
@export var interval: float = 1.0
## Each level multiplies the interval by this (0.8 = 20% faster per level).
@export var interval_scale_per_level: float = 1.0
## Orbit: skull size. Aura, Trail, Eruption, Blast: damage radius. Boomerang: hit
## size. Chain: how far the lightning jumps to the next enemy. Hex: hex size.
## Effigy: burst size.
@export var radius: float = 4.0
@export var radius_per_level: float = 0.0
## Orbit: radians per second. Seeker, Daggers: bolt speed in px/s.
@export var speed: float = 3.0
## Orbit: distance from the player. Seeker, Chain, Eruption, Hex: targeting range.
## Daggers: how far they fly.
## Boomerang: how far the scythe flies out. Blast: how far it clears enemy
## bullets. Effigy: how far it lures enemies.
@export var reach: float = 28.0
## Boomerang: seconds out and back. Trail: how long a flame burns.
## Eruption: warning before the spear strikes. Blast: seconds you can't be hurt.
## Hex: how long enemies stay bound. Effigy: how long it stands.
@export var duration: float = 1.0

@export_group("Evolution")
## Evolved weapons only: the AutoWeapons id this one evolves from (-1 = not an
## evolution), and the passive (Upgrades id) you need alongside the maxed base.
@export var evolves_from: int = -1
@export var catalyst: int = -1
## Boomerang: the sprite thrown (the main weapon's is "scythe"). Daggers: the
## projectile's sprite, pointing right (plus "<sprite>_diag"; see ProjectileManager).
@export var sprite: String = ""


func is_evolution() -> bool:
	return evolves_from >= 0


## Evolutions have a single level; everything else goes to AutoWeapons.MAX_LEVEL.
func max_level() -> int:
	return 1 if is_evolution() else AutoWeapons.MAX_LEVEL


func damage_at(level: int) -> int:
	return damage + damage_per_level * (level - 1)


func count_at(level: int) -> int:
	return count + count_per_level * (level - 1)


func interval_at(level: int) -> float:
	return interval * pow(interval_scale_per_level, level - 1)


func radius_at(level: int) -> float:
	return radius + radius_per_level * (level - 1)
