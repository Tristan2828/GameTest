class_name SpawnEntry
extends Resource
## One line of a stage's spawn table: which enemy, from when, and how common.

@export var enemy_type: int = 0
## Seconds into the stage before this enemy starts appearing.
@export var unlock_time: float = 0.0
@export var weight: float = 1.0
## Extra weight gained per minute after unlocking (makes it more common over time).
@export var weight_per_minute: float = 0.0


func weight_at(elapsed: float) -> float:
	if elapsed < unlock_time:
		return 0.0
	return weight + weight_per_minute * (elapsed - unlock_time) / 60.0
