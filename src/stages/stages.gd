class_name Stages
extends RefCounted
## The stages of a run, in order.

const ALL: Array[StageDef] = [
	preload("res://src/stages/crypt.tres"),
]


## Stage definition for a 1-based stage number (clamped to the last one).
static func get_stage(number: int) -> StageDef:
	return ALL[clampi(number - 1, 0, ALL.size() - 1)]
