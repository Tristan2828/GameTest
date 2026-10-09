class_name EnemyType
extends Resource
## Tunable numbers for one kind of enemy. Each type is a `.tres` file in
## `src/enemies/types/` and is registered in EnemyTypes.ALL. Its index there is
## the id sent over the network.

@export var display_name: String = "Enemy"
@export var max_hp: int = 30
@export var move_speed: float = 40.0
## Body size: used for drawing, bullet hits, and touching players.
@export var radius: float = 6.0
## Hearts removed when it touches a player.
@export var contact_damage: int = 1
@export var xp_value: int = 1
@export var color: Color = Color(0.45, 0.55, 0.4)
## How much the path weaves left and right (radians). 0 = walks straight at you.
@export var wobble: float = 0.0
## Show an HP bar once damaged (for tanky enemies).
@export var show_hp_bar: bool = false

@export_group("Ranged")
## Bullet pattern this enemy fires (ShotPatterns.Id), or -1 for melee only.
@export var shot_pattern: int = -1
## Seconds between volleys.
@export var fire_interval: float = 3.0
## Only fires at players closer than this.
@export var fire_range: float = 260.0
## Tries to stay about this far from its target (0 = walks right up to you).
@export var preferred_distance: float = 0.0
