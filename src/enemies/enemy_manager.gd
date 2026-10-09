class_name EnemyManager
extends Node2D
## Owns a fixed pool of enemies, created once and reused (never freed mid-game).
## Host: moves them, applies damage, and sends compact snapshots to clients.
## Clients: apply those snapshots.

const DUMMY_SCENE: PackedScene = preload("res://src/enemies/dummy_enemy.tscn")
const POOL_SIZE: int = 32
const DUMMY_HP: int = 100
const RESPAWN_DELAY: float = 3.0
const WANDER_RADIUS: float = 14.0
## Radians per second.
const WANDER_SPEED: float = 0.9

## Host: total damage dealt by each peer id. Handy for tests and debugging.
var damage_by_peer: Dictionary[int, int] = {}

var _pool: Array[DummyEnemy] = []
## Host: pool index -> seconds until that dummy respawns.
var _respawn_left: Dictionary[int, float] = {}


func _ready() -> void:
	for i: int in POOL_SIZE:
		var enemy: DummyEnemy = DUMMY_SCENE.instantiate()
		enemy.name = "Enemy%d" % i
		enemy.pool_index = i
		add_child(enemy)
		_pool.append(enemy)


## Host: place training dummies (they slowly circle their spot).
func spawn_dummies(spots: Array[Vector2]) -> void:
	for i: int in mini(spots.size(), POOL_SIZE):
		_pool[i].activate(spots[i], DUMMY_HP)
		_pool[i].wander_phase = TAU * i / spots.size()


func tick_host(delta: float) -> void:
	for enemy: DummyEnemy in _pool:
		if enemy.active:
			enemy.wander_phase = wrapf(enemy.wander_phase + WANDER_SPEED * delta, 0.0, TAU)
			enemy.position = enemy.home + Vector2.from_angle(enemy.wander_phase) * WANDER_RADIUS
	for index: int in _respawn_left.keys():
		_respawn_left[index] -= delta
		if _respawn_left[index] <= 0.0:
			_respawn_left.erase(index)
			_pool[index].activate(_pool[index].home, DUMMY_HP)


## The first active enemy overlapping the circle, or null.
func find_hit(point: Vector2, hit_radius: float) -> DummyEnemy:
	for enemy: DummyEnemy in _pool:
		if not enemy.active:
			continue
		var reach := enemy.radius + hit_radius
		if enemy.position.distance_squared_to(point) <= reach * reach:
			return enemy
	return null


## Host only.
func damage(enemy: DummyEnemy, amount: int, from_peer_id: int) -> void:
	var dealt := mini(amount, enemy.hp)
	var died := enemy.apply_damage(amount)
	damage_by_peer[from_peer_id] = damage_by_peer.get(from_peer_id, 0) + dealt
	if died:
		enemy.deactivate()
		_respawn_left[enemy.pool_index] = RESPAWN_DELAY


func active_count() -> int:
	var total := 0
	for enemy: DummyEnemy in _pool:
		if enemy.active:
			total += 1
	return total


## Host: send every active enemy's id, position and HP to the given peers.
func send_snapshot(peer_ids: Array[int]) -> void:
	var ids := PackedInt32Array()
	var positions := PackedVector2Array()
	var hps := PackedInt32Array()
	for enemy: DummyEnemy in _pool:
		if enemy.active:
			ids.append(enemy.pool_index)
			positions.append(enemy.position)
			hps.append(enemy.hp)
	for peer_id: int in peer_ids:
		_receive_snapshot.rpc_id(peer_id, ids, positions, hps)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_snapshot(ids: PackedInt32Array, positions: PackedVector2Array, hps: PackedInt32Array) -> void:
	var seen: Array[bool] = []
	seen.resize(POOL_SIZE)
	seen.fill(false)
	for i: int in ids.size():
		var index := ids[i]
		if index < 0 or index >= POOL_SIZE:
			continue
		seen[index] = true
		var enemy := _pool[index]
		if not enemy.active:
			enemy.activate(positions[i], DUMMY_HP)
		elif hps[i] < enemy.hp:
			enemy.flash()
		enemy.target_position = positions[i]
		enemy.hp = hps[i]
		enemy.queue_redraw()
	for index: int in POOL_SIZE:
		if not seen[index] and _pool[index].active:
			_pool[index].deactivate()
