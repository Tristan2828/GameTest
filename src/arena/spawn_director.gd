class_name SpawnDirector
extends RefCounted
## Decides when and what to spawn (host only). Pure logic with no nodes, so it's
## easy to test and tune. The arena asks it every tick and places the enemies.
##
## - Steady trickle that ramps up over the stage.
## - More players = more enemies (same toughness).
## - Every so often, a "pack surge": a tight cluster from one direction.
## - Tougher/faster types unlock as time passes.

const BASE_SPAWNS_PER_SECOND: float = 1.0
## Extra spawns per second gained every second of the stage.
const RAMP_PER_SECOND: float = 0.025
## +60% spawn rate for each player beyond the first.
const EXTRA_PLAYER_MULTIPLIER: float = 0.6
const MAX_ALIVE: int = 260
const PACK_SIZE: int = 12
const PACK_INTERVAL_MIN: float = 35.0
const PACK_INTERVAL_MAX: float = 50.0
const BAT_UNLOCK_TIME: float = 45.0
const GHOUL_UNLOCK_TIME: float = 90.0
const CULTIST_UNLOCK_TIME: float = 120.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _budget: float = 0.0
var _next_pack_time: float = 0.0


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value
	_next_pack_time = rng.randf_range(PACK_INTERVAL_MIN, PACK_INTERVAL_MAX)


static func spawns_per_second(elapsed: float, player_count: int) -> float:
	var players := maxi(player_count, 1)
	return (BASE_SPAWNS_PER_SECOND + elapsed * RAMP_PER_SECOND) * (1.0 + EXTRA_PLAYER_MULTIPLIER * (players - 1))


## Enemy type ids to spawn individually this tick.
func tick(delta: float, elapsed: float, player_count: int, alive: int) -> Array[int]:
	var result: Array[int] = []
	_budget += spawns_per_second(elapsed, player_count) * delta
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


## Weighted pick; later types join the mix (and grow more common) over time.
func pick_type(elapsed: float) -> int:
	var shambler_weight := 10.0
	var bat_weight := 0.0 if elapsed < BAT_UNLOCK_TIME else 4.0
	var ghoul_weight := 0.0 if elapsed < GHOUL_UNLOCK_TIME else 1.5 + (elapsed - GHOUL_UNLOCK_TIME) / 60.0
	var cultist_weight := 0.0 if elapsed < CULTIST_UNLOCK_TIME else 2.5
	var roll := rng.randf() * (shambler_weight + bat_weight + ghoul_weight + cultist_weight)
	if roll < shambler_weight:
		return EnemyTypes.Id.SHAMBLER
	if roll < shambler_weight + bat_weight:
		return EnemyTypes.Id.BAT
	if roll < shambler_weight + bat_weight + ghoul_weight:
		return EnemyTypes.Id.GHOUL
	return EnemyTypes.Id.CULTIST
