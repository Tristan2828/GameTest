class_name Characters
extends RefCounted
## Registry of playable characters. The index in ALL is the network id: only add
## new characters at the end.

enum Id { WANDERER, GRAVEKEEPER, HEXBLADE_WITCH, NECROMANCER }

const ALL: Array[CharacterStats] = [
	preload("res://src/player/characters/wanderer.tres"),
	preload("res://src/player/characters/gravekeeper.tres"),
	preload("res://src/player/characters/hexblade_witch.tres"),
	preload("res://src/player/characters/necromancer.tres"),
]


static func get_character(id: int) -> CharacterStats:
	return ALL[clampi(id, 0, ALL.size() - 1)]


static func is_valid_id(id: int) -> bool:
	return id >= 0 and id < ALL.size()


## The starting damage of the hero with this main weapon (each hero has their own).
static func base_damage(main_weapon: int) -> int:
	for character: CharacterStats in ALL:
		if character.main_weapon == main_weapon:
			return character.bullet_damage
	return 10
