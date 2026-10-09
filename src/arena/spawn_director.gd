class_name SpawnDirector
extends RefCounted
## Decides when and what to spawn (host only). Pure logic with no nodes, so it's
## easy to test and tune. The arena asks it every tick and places the enemies.
##
## - Steady trickle that ramps up over the stage.
## - More players = more enemies (same toughness).
## - Every so often, a "pack surge": a tight cluster from one direction.
## - Which enemies appear, and when, comes from the stage's spawn table.

const BASE_SPAWNS_PER_SECOND: float = 1.0
## Extra spawns per second gained every second of the stage.
const RAMP_PER_SECOND: float = 0.025
## +60% spawn rate for each player beyond the first.
const EXTRA_PLAYER_MULTIPLIER: float = 0.6
const MAX_ALIVE: int = 260
const PACK_SIZE: int = 12
const PACK_INTERVAL_MIN: float = 35.0
const PACK_INTERVAL_MAX: float = 50.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var spawns: Array[SpawnEntry] = []

var _budget: float = 0.0
var _next_pack_time: float = 0.0


## Without a table, uses the first stage's.
func _init(seed_value: int = 0, spawn_table: Array[SpawnEntry] = []) -> void:
	rng.seed = seed_value
	spawns = spawn_table if not spawn_table.is_empty() else Stages.get_stage(1).spawns
	_next_pack_time = rng.randf_range(PACK_INTERVAL_MIN, PACK_INTERVAL_MAX)


static func spawns_per_second(elapsed: float, player_count: int) -> float:
	var players := maxi(player_count, 1)
	return (BASE_SPAWNS_PER_SECOND + elapsed * RAMP_PER_SECOND) * (1.0 + EXTRA_PLAYER_MULTIPLIER * (players - 1))


## Enemy type ids to spawn individually this tick.
## `rate_multiplier` scales the spawn rate (e.g. lower during the boss fight).
func tick(delta: float, elapsed: float, player_count: int, alive: int, rate_multiplier: float = 1.0) -> Array[int]:
	var result: Array[int] = []
	_budget += spawns_per_second(elapsed, player_count) * rate_multiplier * delta
	while _budget >= 1.0:
		_budget -= 1.0
		if alive + result.size() < MAX_ALIVE:
			result.append(pick_type(elapsed))
	return result


## True once per pack interval; the arena then spawns PACK_SIZE shamblers together.
func pack_due(elapsed: float, alive: int) -> bool:
	if elapsed < _next_pack_time:
		return false
	_next_pack_time = elapsed + rng.randf_range(PACK_INTERVAL_MIN, PACK_INTERVAL_MAX)
	return alive + PACK_SIZE <= MAX_ALIVE


## Weighted pick from the spawn table; later types join the mix over time.
func pick_type(elapsed: float) -> int:
	var total := 0.0
	for entry: SpawnEntry in spawns:
		total += entry.weight_at(elapsed)
	var roll := rng.randf() * total
	for entry: SpawnEntry in spawns:
		roll -= entry.weight_at(elapsed)
		if roll < 0.0:
			return entry.enemy_type
	return spawns[0].enemy_type
