class_name CharacterStats
extends Resource
## Tunable numbers for one playable character. Each character gets a `.tres` file
## in `src/player/characters/`, registered in Characters.ALL (index = network id).
## Each player duplicates their character's stats, and upgrades/relics change the copy.

enum Look { HOOD, WIDE_HAT, WITCH_HAT }

@export var display_name: String = "Wanderer"
@export_multiline var blurb: String = ""
@export var look: Look = Look.HOOD

@export_group("Ability")
@export var ability_name: String = ""
@export_multiline var ability_description: String = ""
## Second Wind: the first lethal hit each stage leaves you at 1 heart instead.
@export var second_wind: bool = false
## Grave Ward: hearts healed by each of your bombs.
@export var bomb_heal: int = 0

@export_group("Movement")
@export var move_speed: float = 110.0
@export var dash_speed: float = 340.0
@export var dash_duration: float = 0.16
## Counted from the start of the dash.
@export var dash_cooldown: float = 0.8

@export_group("Health")
@export var max_hearts: int = 3
## Seconds of invulnerability after taking a hit.
@export var hit_invulnerability: float = 1.0
## Bombs at the start of each stage.
@export var bombs_per_stage: int = 2
## Bomb damage is multiplied by this (relics raise it).
@export var bomb_damage_multiplier: float = 1.0
## Heal 1 heart every this many kills (0 = never; from relics).
@export var heal_every_kills: int = 0

@export_group("Body")
## Size used for drawing and keeping the player inside the arena.
@export var body_radius: float = 6.0
## The much smaller circle that enemy bullets must touch to hurt the player.
@export var hitbox_radius: float = 2.0
## XP gems within this distance fly to the player.
@export var pickup_radius: float = 40.0

@export_group("Main gun")
@export var shot_pattern: ShotPatterns.Id = ShotPatterns.Id.BASIC
@export var fire_interval: float = 0.12
@export var bullet_speed: float = 320.0
@export var bullet_damage: int = 10
@export var bullet_lifetime: float = 1.2
## Bolts per shot, fanned out around the aim direction.
@export var projectile_count: int = 1
## Extra enemies each bolt can pass through.
@export var pierce: int = 0
