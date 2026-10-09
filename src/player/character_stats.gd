class_name CharacterStats
extends Resource
## Tunable numbers for one playable character. Each character gets a `.tres` file
## in `src/player/characters/` so values can be tweaked without touching code.

@export var display_name: String = "Wanderer"

@export_group("Movement")
@export var move_speed: float = 110.0
@export var dash_speed: float = 340.0
@export var dash_duration: float = 0.16
## Counted from the start of the dash.
@export var dash_cooldown: float = 0.8

@export_group("Body")
## Size used for drawing and keeping the player inside the arena.
@export var body_radius: float = 6.0
## The much smaller circle that enemy bullets must touch to hurt the player.
@export var hitbox_radius: float = 2.0

@export_group("Main gun")
@export var shot_pattern: ShotPatterns.Id = ShotPatterns.Id.BASIC
@export var fire_interval: float = 0.12
@export var bullet_speed: float = 320.0
@export var bullet_damage: int = 10
@export var bullet_lifetime: float = 1.2
