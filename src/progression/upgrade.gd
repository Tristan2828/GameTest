class_name Upgrade
extends Resource
## One stat effect. Used as a level-up choice (`src/progression/upgrades/`,
## registered in Upgrades.ALL, index = network id) and as an effect inside relics.

## Stored as numbers in .tres files: only add new stats at the end.
## v0.22.0: MAX_HP counted hearts and AUTO_COOLDOWN / AUTO_POWER were the
## ability's; DASH_GRACE to EFFIGY_BURST belonged to the heroes' button abilities
## and do nothing now (kept so the numbers stay stable).
enum Stat {
	DAMAGE, FIRE_RATE, MOVE_SPEED, MAX_HP, EXTRA_BOLT, PIERCE, PICKUP_RADIUS, AUTO_COOLDOWN, HEAL,
	AUTO_POWER, BULLET_SPEED, KILL_HEAL, REVIVE_SPEED,
	BULLET_RANGE, HIT_INVULNERABILITY, CRIT_CHANCE, KILL_BURST, BOSS_DAMAGE, WOUNDED_DAMAGE,
	RICOCHET, HOMING, DASH_GRACE, BLAST_DAMAGE, BLAST_HEAL, HEX_DURATION, HEX_DAMAGE,
	EFFIGY_DURATION, EFFIGY_BURST,
	WEAPON_REACH, WEAPON_SIZE, WEAPON_DELAY, CHAIN_GROWTH, CHAIN_FORK, SCYTHE_CUTS, SPEAR_SHARDS,
	RECOVERY,
}

@export var title: String = "Upgrade"
## PixelArt sprite shown on cards and the run summary.
@export var icon: String = ""
@export_multiline var description: String = ""
@export var stat: Stat = Stat.DAMAGE
## Meaning depends on the stat: flat amount for DAMAGE/MAX_HP/EXTRA_BOLT/PIERCE/HEAL/
## KILL_BURST/RICOCHET/CHAIN_FORK/SCYTHE_CUTS/SPEAR_SHARDS, seconds for HIT_INVULNERABILITY,
## HP per second for RECOVERY, radians per second for HOMING, kills per HP healed for
## KILL_HEAL, and a fraction (0.1 = 10%; REVIVE_SPEED +1.0 = twice as fast) for the
## others. Can be negative.
@export var amount: float = 1.0
## How many times one player can take it. 0 = no limit.
@export var max_stacks: int = 0
## No longer offered (the four hero-ability upgrades since v0.22.0). Kept so ids stay stable.
@export var retired: bool = false
## Only offered to heroes with this CharacterStats.MainWeapon (-1 = everyone).
@export var for_weapon: int = -1
## More effects applied together with this one (e.g. a trade-off's downside).
## Upgrade resources; typed as Resource because a script can't hold a typed
## array of itself without leaking.
@export var extra_effects: Array[Resource] = []
