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


static func of_weapon(weapon_id: int) -> int:
	return FIRST_WEAPON + weapon_id


## The AutoWeapons id, or -1 for the main gun / ability.
static func weapon_id(source: int) -> int:
	return source - FIRST_WEAPON if source >= FIRST_WEAPON and source < KILL_BURST else -1


## "Main gun", the ability's name, or the weapon's name.
static func title(source: int, stats: CharacterStats) -> String:
	match source:
		MAIN_GUN:
			return "Main gun"
		ABILITY:
			return stats.ability_name
		KILL_BURST:
			return "Corpse Blast"
	var id := weapon_id(source)
	return AutoWeapons.get_weapon(id).title if id >= 0 and id < AutoWeapons.ALL.size() else "?"


## PixelArt sprite for the breakdown rows.
static func icon(source: int) -> String:
	match source:
		MAIN_GUN:
			return "icon_main_gun"
		ABILITY:
			return "icon_ability"
		KILL_BURST:
			return "up_corpse_blast"
	var id := weapon_id(source)
	return AutoWeapons.get_weapon(id).icon if id >= 0 and id < AutoWeapons.ALL.size() else ""
