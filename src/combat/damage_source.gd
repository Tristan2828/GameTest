class_name DamageSource
extends RefCounted
## What dealt a hit, for the end-of-run weapon breakdown (the host counts it).
## Sent as numbers: the main gun, the character's ability, then one id per auto
## weapon (FIRST_WEAPON + AutoWeapons id, which is append-only too).

const MAIN_GUN: int = 0
const ABILITY: int = 1
const FIRST_WEAPON: int = 2
## Corpse Blast bursts (an upgrade, not a weapon). Far above the weapon ids.
const KILL_BURST: int = 250
## Holy Bomb pickups.
const HOLY_BOMB: int = 251


static func of_weapon(weapon_id: int) -> int:
	return FIRST_WEAPON + weapon_id


## The AutoWeapons id, or -1 for the main gun / ability.
static func weapon_id(source: int) -> int:
	return source - FIRST_WEAPON if source >= FIRST_WEAPON and source < KILL_BURST else -1


## The main weapon's or ability's name, or the auto weapon's name.
static func title(source: int, stats: CharacterStats) -> String:
	match source:
		MAIN_GUN:
			return stats.main_weapon_name
		ABILITY:
			return stats.ability_name
		KILL_BURST:
			return "Corpse Blast"
		HOLY_BOMB:
			return "Holy Bomb"
	var id := weapon_id(source)
	return AutoWeapons.get_weapon(id).title if id >= 0 and id < AutoWeapons.ALL.size() else "?"


## PixelArt sprite for the breakdown rows (`stats` picks the main weapon's).
static func icon(source: int, stats: CharacterStats = null) -> String:
	match source:
		MAIN_GUN:
			return stats.main_weapon_icon if stats != null else "icon_main_gun"
		ABILITY:
			return "icon_ability"
		KILL_BURST:
			return "up_corpse_blast"
		HOLY_BOMB:
			return "pickup_bomb"
	var id := weapon_id(source)
	return AutoWeapons.get_weapon(id).icon if id >= 0 and id < AutoWeapons.ALL.size() else ""
