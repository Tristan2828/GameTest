class_name EnemyTypes
extends RefCounted
## Registry of every enemy type. The index in ALL is the type id used in network
## messages, so only ever add new types at the end.

enum Id {
	SHAMBLER, BAT, GHOUL, CULTIST, BONE_WARDEN,
	MIRE_CRAWLER, PLAGUE_SPITTER, FLAME_IMP, FALLEN_PALADIN, MIRE_HAG, ASHEN_BISHOP,
	GHOUL_CHAMPION, PLAGUE_CHAMPION, PALADIN_CHAMPION, GRAVE_ROBBER,
}

const ALL: Array[EnemyType] = [
	preload("res://src/enemies/types/shambler.tres"),
	preload("res://src/enemies/types/bat.tres"),
	preload("res://src/enemies/types/ghoul.tres"),
	preload("res://src/enemies/types/cultist.tres"),
	preload("res://src/enemies/types/bone_warden.tres"),
	preload("res://src/enemies/types/mire_crawler.tres"),
	preload("res://src/enemies/types/plague_spitter.tres"),
	preload("res://src/enemies/types/flame_imp.tres"),
	preload("res://src/enemies/types/fallen_paladin.tres"),
	preload("res://src/enemies/types/mire_hag.tres"),
	preload("res://src/enemies/types/ashen_bishop.tres"),
	preload("res://src/enemies/types/ghoul_champion.tres"),
	preload("res://src/enemies/types/plague_champion.tres"),
	preload("res://src/enemies/types/paladin_champion.tres"),
	preload("res://src/enemies/types/grave_robber.tres"),
]


static func get_type(id: int) -> EnemyType:
	return ALL[clampi(id, 0, ALL.size() - 1)]
