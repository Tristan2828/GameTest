class_name EnemyTypes
extends RefCounted
## Registry of every enemy type. The index in ALL is the type id used in network
## messages, so only ever add new types at the end.

enum Id { SHAMBLER, BAT, GHOUL, CULTIST }

const ALL: Array[EnemyType] = [
	preload("res://src/enemies/types/shambler.tres"),
	preload("res://src/enemies/types/bat.tres"),
	preload("res://src/enemies/types/ghoul.tres"),
	preload("res://src/enemies/types/cultist.tres"),
]


static func get_type(id: int) -> EnemyType:
	return ALL[clampi(id, 0, ALL.size() - 1)]
