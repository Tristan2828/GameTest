class_name Upgrade
extends Resource
## One stat effect. Used as a level-up choice (`src/progression/upgrades/`,
## registered in Upgrades.ALL, index = network id) and as an effect inside relics.

## Stored as numbers in .tres files: only add new stats at the end.
enum Stat {
	DAMAGE, FIRE_RATE, MOVE_SPEED, MAX_HEARTS, EXTRA_BOLT, PIERCE, PICKUP_RADIUS, ABILITY_COOLDOWN, HEAL,
	ABILITY_POWER, BULLET_SPEED, KILL_HEAL, REVIVE_SPEED,
}

@export var title: String = "Upgrade"
@export_multiline var description: String = ""
@export var stat: Stat = Stat.DAMAGE
## Meaning depends on the stat: flat amount for DAMAGE/MAX_HEARTS/EXTRA_BOLT/PIERCE/HEAL,
## kills per heal for KILL_HEAL, a fraction (REVIVE_SPEED: +1.0 = twice as fast) (0.1 = 10%) for the others. Can be negative.
@export var amount: float = 1.0
## How many times one player can take it. 0 = no limit.
@export var max_stacks: int = 0
