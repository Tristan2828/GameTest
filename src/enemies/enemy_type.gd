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
## Chance (0..1) to drop a coin on death, and what it's worth.
@export var coin_chance: float = 0.1
@export var coin_value: int = 1
@export var color: Color = Color(0.45, 0.55, 0.4)
## How much the path weaves left and right (radians). 0 = walks straight at you.
@export var wobble: float = 0.0
## Show an HP bar once damaged (for tanky enemies).
@export var show_hp_bar: bool = false

## PixelArt sprite name. Animated sprites add frames named "<sprite>_1", ...
@export var sprite: String = ""
@export var sprite_frames: int = 1
## Bosses are drawn at 2x.
@export var sprite_scale: float = 1.0

## Bosses get the big HUD health bar and end the stage when they die.
@export var is_boss: bool = false
## Extra max HP per player beyond the first (0.75 = +75%). Regular enemies use 0.
@export var hp_per_extra_player: float = 0.0

@export_group("Ranged")
## Bullet pattern this enemy fires (ShotPatterns.Id), or -1 for melee only.
@export var shot_pattern: int = -1
## Seconds between volleys.
@export var fire_interval: float = 3.0
## Only fires at players closer than this.
@export var fire_range: float = 260.0
## Tries to stay about this far from its target (0 = walks right up to you).
@export var preferred_distance: float = 0.0
