class_name Upgrade
extends Resource
## One level-up choice. Each is a `.tres` file in `src/progression/upgrades/`,
## registered in Upgrades.ALL (its index there is the network id).

enum Stat { DAMAGE, FIRE_RATE, MOVE_SPEED, MAX_HEARTS, EXTRA_BOLT, PIERCE, PICKUP_RADIUS, DASH_COOLDOWN, HEAL }

@export var title: String = "Upgrade"
@export_multiline var description: String = ""
@export var stat: Stat = Stat.DAMAGE
## Meaning depends on the stat: flat amount for DAMAGE/MAX_HEARTS/EXTRA_BOLT/PIERCE/HEAL,
## a fraction (0.1 = 10%) for the others.
@export var amount: float = 1.0
## How many times one player can take it. 0 = no limit.
@export var max_stacks: int = 0
