class_name CharacterStats
extends Resource
## Tunable numbers for one playable character. Each character gets a `.tres` file
## in `src/player/characters/`, registered in Characters.ALL (index = network id).
## Each player duplicates their character's stats, and upgrades/relics change the copy.

## Each character has one ability on the ability button. Stored as numbers in
## .tres files: only add new abilities at the end.
## (BLINK is no longer used by anyone; kept so the numbers stay stable.)
enum Ability { DASH, GRAVE_BLAST, BLINK, HEX_SNARE, BONE_EFFIGY }
## Each character's main weapon (aimed, on the fire button). Stored as numbers in
## .tres files and sent over the network: only add new ones at the end.
enum MainWeapon { BOLTS, SCYTHE, LIGHTNING, SPEARS }

@export var display_name: String = "Wanderer"
@export_multiline var blurb: String = ""
## PixelArt sprite name (P/p pixels take the player's color).
@export var sprite: String = "wanderer"

@export_group("Ability")
@export var ability: Ability = Ability.DASH
@export var ability_name: String = "Dash"
@export_multiline var ability_description: String = ""
## Seconds before the ability can be used again.
@export var ability_cooldown: float = 0.8
## Multiplies how strong the ability is (relics raise it): dash length, blink
## distance, blast size and damage.
@export var ability_power: float = 1.0
## Dash: speed and duration (you can't be hit while dashing).
@export var dash_speed: float = 340.0
@export var dash_duration: float = 0.16
## Seconds you stay untouchable after a Dash ends (from upgrades).
@export var dash_grace: float = 0.0
## Blink: how far you teleport, and how long you're untouchable after.
@export var blink_distance: float = 90.0
@export var blink_invulnerability: float = 0.4
## Grave Blast: clears enemy bullets, damages enemies, heals, protects.
@export var blast_clear_radius: float = 220.0
@export var blast_damage_radius: float = 90.0
@export var blast_damage: int = 60
@export var blast_heal: int = 1
@export var blast_invulnerability: float = 1.5
## Hex Snare: a hex lands this far ahead (in the aim direction). Enemies inside
## can't move or attack and take extra damage. Bosses aren't rooted.
@export var hex_range: float = 80.0
@export var hex_radius: float = 55.0
@export var hex_duration: float = 3.0
## Damage multiplier on hexed enemies (1.5 = +50%).
@export var hex_damage_multiplier: float = 1.5
## Bone Effigy: a decoy raised this far ahead. Enemies within the lure radius
## chase it instead of players; it bursts when it expires.
@export var effigy_range: float = 40.0
@export var effigy_duration: float = 4.0
@export var effigy_lure_radius: float = 150.0
@export var effigy_burst_radius: float = 70.0
@export var effigy_burst_damage: int = 45

@export_group("Movement")
@export var move_speed: float = 110.0

@export_group("Health")
@export var max_hearts: int = 3
## Seconds of invulnerability after taking a hit.
@export var hit_invulnerability: float = 1.0
## Heal 1 heart every this many kills (0 = never; from relics).
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

@export_group("Main weapon")
@export var main_weapon: MainWeapon = MainWeapon.BOLTS
@export var main_weapon_name: String = "Bolt Gun"
## PixelArt sprite for the Game Guide and the run summary's Weapons page.
@export var main_weapon_icon: String = "icon_main_gun"
## Seconds between attacks while fire is held.
@export var fire_interval: float = 0.12
## Damage of one bolt, scythe cut, lightning strike or spear.
@export var bullet_damage: int = 10
## Bolts per shot, fanned out around the aim direction. Scythe: scythes per
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
