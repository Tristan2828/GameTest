class_name CharacterStats
extends Resource
## Tunable numbers for one playable character. Each character gets a `.tres` file
## in `src/player/characters/`, registered in Characters.ALL (index = network id).
## Each player duplicates their character's stats, and upgrades/relics change the copy.

## Each character's main weapon (fires on its own; see AutoAim for how each one
## picks a target). Stored as numbers in .tres files and sent over the network:
## only add new ones at the end.
enum MainWeapon { BOLTS, SCYTHE, LIGHTNING, SPEARS }

## The hero's class ("Wanderer"); shown under their name.
@export var display_name: String = "Wanderer"
## The hero's own name ("Kael"), shown first in menus and on the run summary.
@export var hero_name: String = "Kael"
@export_multiline var blurb: String = ""
## PixelArt sprite name (P/p pixels take the player's color).
@export var sprite: String = "wanderer"

@export_group("Perk")
## The hero's small passive bonus, shown in menus (its effect is in the numbers below).
@export var perk_name: String = ""
@export_multiline var perk_description: String = ""

@export_group("Auto weapons")
## Multiplies every auto weapon's time between attacks (0.8 = 20% faster). From
## relics and the Ember Shrine's Focus.
@export var auto_cooldown_scale: float = 1.0
## Multiplies every auto weapon's damage (and Hex Snare / Bone Effigy durations).
@export var auto_power: float = 1.0

@export_group("Movement")
@export var move_speed: float = 110.0

@export_group("Health")
@export var max_hp: int = 100
## Seconds an enemy bullet can't hit you again after one did. Touching enemies
## isn't blocked by it.
@export var hit_invulnerability: float = 0.5
## HP regenerated per second (Recovery).
@export var recovery: float = 0.0
## Heal 1 HP every this many kills (0 = never; from relics).
@export var heal_every_kills: int = 0
## How fast this player revives downed teammates (1 = normal, 2 = twice as fast).
## Raised by relics; a future support character could start higher.
@export var revive_speed: float = 1.0

@export_group("Body")
## Size used for drawing and keeping the player inside the arena.
@export var body_radius: float = 6.0
## The much smaller circle that enemy bullets must touch to hurt the player.
@export var hitbox_radius: float = 2.0
## XP gems within this distance fly to the player.
@export var pickup_radius: float = 40.0
## Chance (0..1) that a coin this player picks up is worth 1 more (Ember Shrine's Greed).
@export var coin_luck: float = 0.0

@export_group("Main weapon")
@export var main_weapon: MainWeapon = MainWeapon.BOLTS
@export var main_weapon_name: String = "Bolt Gun"
## PixelArt sprite for the Game Guide and the run summary's Weapons page.
@export var main_weapon_icon: String = "icon_main_gun"
## Seconds between attacks.
@export var fire_interval: float = 0.12
## Damage of one bolt, scythe cut, lightning strike or spear.
@export var bullet_damage: int = 10
## Bolts per shot, fanned out around the target. Scythe: scythes per
## throw. Lightning: jumps after the first strike. Spears: spears in the row.
@export var projectile_count: int = 1
## Bolts only (and Bone Spears' Splinters shards use their own numbers).
@export var shot_pattern: ShotPatterns.Id = ShotPatterns.Id.BASIC
@export var bullet_speed: float = 320.0
@export var bullet_lifetime: float = 1.2
## Extra enemies each bolt can pass through.
@export var pierce: int = 0
## Times each bolt bounces to another nearby enemy after its last hit.
@export var ricochet: int = 0
## How fast bolts turn toward the nearest enemy, in radians per second (0 = straight).
@export var homing: float = 0.0
## Chance (0..1) that a main-weapon hit deals double damage.
@export var crit_chance: float = 0.0
## Scythe: how far it flies out. Lightning: how far the first strike reaches.
@export var weapon_reach: float = 0.0
## Scythe: hit size. Lightning: how far it jumps to the next enemy. Spears: strike radius.
@export var weapon_radius: float = 0.0
## Scythe: seconds out and back. Spears: warning before the first spear strikes.
@export var weapon_duration: float = 0.0
## Scythe: how often it can cut the same enemy in one throw.
@export var scythe_cuts: int = 2
## Lightning: each jump hits this much harder than the one before (0.2 = +20%).
@export var chain_damage_growth: float = 0.0
## Lightning: extra chains that split off at the first enemy hit.
@export var chain_forks: int = 0
## Spears: bone shards each spear sprays out when it strikes.
@export var spear_shards: int = 0

@export_group("Damage bonuses")
## Extra damage (fraction) against bosses, from every source.
@export var boss_damage_bonus: float = 0.0
## Extra damage (fraction) against enemies below half health, from every source.
@export var wounded_damage_bonus: float = 0.0
## Enemies this player kills burst for this much damage around them (0 = no burst).
@export var kill_burst_damage: int = 0


## "Kael the Wanderer".
func full_name() -> String:
	return "%s the %s" % [hero_name, display_name]
