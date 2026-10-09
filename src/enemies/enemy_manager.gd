class_name EnemyManager
extends Node2D
## Owns a fixed pool of enemies, created once and reused (never freed mid-game).
## Host: moves them toward players, applies damage, and sends compact snapshots.
## Clients: apply those snapshots.
## All peers: keep a SpatialGrid of enemy positions for fast hit checks.

signal enemy_killed(enemy: Enemy, killer_peer_id: int)
## Every peer: an enemy just disappeared here (for death effects).
signal enemy_vanished(at: Vector2, color: Color, radius: float)
## Host: a ranged enemy fired. The arena turns this into bullets + a network event.
signal pattern_fired(pattern: int, origin: Vector2, aim: float)

const ENEMY_SCENE: PackedScene = preload("res://src/enemies/enemy.tscn")
const POOL_SIZE: int = 300
const GRID_CELL_SIZE: float = 24.0
## Larger than any enemy radius; used to find touching neighbours.
const MAX_ENEMY_RADIUS: float = 24.0
## How hard overlapping enemies push each other apart.
const SEPARATION_STRENGTH: float = 40.0
## Each enemy in a snapshot: u16 index, u8 type, u8 flags, s16 x, s16 y, u8 hp.
const SNAPSHOT_STRIDE: int = 9
const FLAG_HIT: int = 1

## Host: total damage dealt by each peer id. Handy for tests and debugging.
var damage_by_peer: Dictionary[int, int] = {}
var bounds: Rect2 = Rect2(-10000, -10000, 20000, 20000)

var _pool: Array[Enemy] = []
var _free_indices: Array[int] = []
var _grid: SpatialGrid = SpatialGrid.new(GRID_CELL_SIZE)
var _nearby: Array[int] = []


func _ready() -> void:
	for i: int in POOL_SIZE:
		var enemy: Enemy = ENEMY_SCENE.instantiate()
		enemy.name = "Enemy%d" % i
		enemy.pool_index = i
		add_child(enemy)
		_pool.append(enemy)
	for i: int in range(POOL_SIZE - 1, -1, -1):
		_free_indices.append(i)


## Host: returns the spawned enemy, or null if the pool is full.
func spawn(type_id: int, at: Vector2, hit_points: int = 0) -> Enemy:
	if _free_indices.is_empty():
		return null
	var enemy := _pool[_free_indices.pop_back()]
	enemy.activate(type_id, at, hit_points)
	return enemy


## The closest active enemy within `max_distance`, or null.
func find_nearest(point: Vector2, max_distance: float) -> Enemy:
	var best: Enemy = null
	var best_distance := max_distance * max_distance
	for enemy: Enemy in _pool:
		if not enemy.active:
			continue
		var distance := enemy.position.distance_squared_to(point)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## The active boss, or null.
func find_boss() -> Enemy:
	for enemy: Enemy in _pool:
		if enemy.active and enemy.type.is_boss:
			return enemy
	return null


func active_count() -> int:
	var total := 0
	for enemy: Enemy in _pool:
		if enemy.active:
			total += 1
	return total


## Host: move every enemy toward the nearest target, pushing apart overlaps.
func tick_host(delta: float, targets: Array[Vector2]) -> void:
	rebuild_grid()
	for enemy: Enemy in _pool:
		if not enemy.active:
			continue
		var velocity := Vector2.ZERO
		if not targets.is_empty():
			var to_target := _nearest(targets, enemy.position) - enemy.position
			velocity = _desired_velocity(enemy, to_target, delta)
			_try_fire(enemy, to_target, delta)
		velocity += _separation(enemy) * SEPARATION_STRENGTH
		var inner := bounds.grow(-enemy.type.radius)
		enemy.position = (enemy.position + velocity * delta).clamp(inner.position, inner.end)
	rebuild_grid()


## All peers, after positions change.
func rebuild_grid() -> void:
	_grid.clear()
	for enemy: Enemy in _pool:
		if enemy.active:
			_grid.insert(enemy.pool_index, enemy.position)


## The first active enemy overlapping the circle, or null.
func find_hit(point: Vector2, hit_radius: float) -> Enemy:
	_nearby.clear()
	_grid.query(point, hit_radius + MAX_ENEMY_RADIUS, _nearby)
	for index: int in _nearby:
		var enemy := _pool[index]
		if not enemy.active:
			continue
		var reach := enemy.type.radius + hit_radius
		if enemy.position.distance_squared_to(point) <= reach * reach:
			return enemy
	return null


## Host: damage every active enemy within `radius` (bombs).
func damage_in_radius(center: Vector2, radius: float, amount: int, from_peer_id: int) -> void:
	var targets: Array[Enemy] = []
	_nearby.clear()
	_grid.query(center, radius + MAX_ENEMY_RADIUS, _nearby)
	for index: int in _nearby:
		var enemy := _pool[index]
		var reach := radius + enemy.type.radius
		if enemy.active and enemy.position.distance_squared_to(center) <= reach * reach:
			targets.append(enemy)
	for enemy: Enemy in targets:
		if enemy.active:
			damage(enemy, amount, from_peer_id)


## Host only.
func damage(enemy: Enemy, amount: int, from_peer_id: int) -> void:
	var dealt := mini(amount, enemy.hp)
	var died := enemy.apply_damage(amount)
	damage_by_peer[from_peer_id] = damage_by_peer.get(from_peer_id, 0) + dealt
	if died:
		_release(enemy)
		enemy_killed.emit(enemy, from_peer_id)


## Host: remove every enemy (e.g. when the stage ends).
func clear_all() -> void:
	for enemy: Enemy in _pool:
		if enemy.active:
			_release(enemy)
	rebuild_grid()


## Host: pack every active enemy into bytes and send them to the given peers.
func send_snapshot(peer_ids: Array[int]) -> void:
	var count := active_count()
	var data := PackedByteArray()
	data.resize(count * SNAPSHOT_STRIDE)
	var offset := 0
	for enemy: Enemy in _pool:
		if not enemy.active:
			continue
		data.encode_u16(offset, enemy.pool_index)
		data.encode_u8(offset + 2, enemy.type_id)
		data.encode_u8(offset + 3, FLAG_HIT if enemy.hit_since_snapshot else 0)
		data.encode_s16(offset + 4, clampi(roundi(enemy.position.x), -32768, 32767))
		data.encode_s16(offset + 6, clampi(roundi(enemy.position.y), -32768, 32767))
		data.encode_u8(offset + 8, roundi(enemy.hp_ratio * 255.0))
		enemy.hit_since_snapshot = false
		offset += SNAPSHOT_STRIDE
	for peer_id: int in peer_ids:
		# The count is also what keeps the RPC valid when there are no enemies:
		# an empty byte array as the only argument arrives as "no arguments".
		_receive_snapshot.rpc_id(peer_id, count, data)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_snapshot(count: int, data: PackedByteArray) -> void:
	var seen: Array[bool] = []
	seen.resize(POOL_SIZE)
	seen.fill(false)
	for offset: int in range(0, mini(count * SNAPSHOT_STRIDE, data.size() - SNAPSHOT_STRIDE + 1), SNAPSHOT_STRIDE):
		var index := data.decode_u16(offset)
		if index >= POOL_SIZE:
			continue
		seen[index] = true
		var enemy := _pool[index]
		var type_id := data.decode_u8(offset + 2)
		var at := Vector2(data.decode_s16(offset + 4), data.decode_s16(offset + 6))
		if not enemy.active or enemy.type_id != type_id:
			enemy.activate(type_id, at)
		if data.decode_u8(offset + 3) & FLAG_HIT:
			enemy.flash()
		enemy.target_position = at
		var ratio := data.decode_u8(offset + 8) / 255.0
		if not is_equal_approx(ratio, enemy.hp_ratio):
			enemy.hp_ratio = ratio
			enemy.queue_redraw()
	for index: int in POOL_SIZE:
		if not seen[index] and _pool[index].active:
			var gone := _pool[index]
			enemy_vanished.emit(gone.position, gone.type.color, gone.type.radius)
			gone.deactivate()


func _desired_velocity(enemy: Enemy, to_target: Vector2, delta: float) -> Vector2:
	var direction := to_target.normalized()
	var preferred := enemy.type.preferred_distance
	if preferred > 0.0:
		var distance := to_target.length()
		if distance < preferred - 20.0:
			direction = -direction
		elif distance <= preferred + 30.0:
			# In the comfort zone: circle around the target instead.
			direction = direction.orthogonal() * (1.0 if enemy.pool_index % 2 == 0 else -1.0)
	if enemy.type.wobble > 0.0:
		enemy.wobble_phase += delta * 5.0
		direction = direction.rotated(sin(enemy.wobble_phase) * enemy.type.wobble)
	return direction * enemy.type.move_speed


func _try_fire(enemy: Enemy, to_target: Vector2, delta: float) -> void:
	if enemy.type.shot_pattern < 0:
		return
	enemy.fire_cooldown -= delta
	if enemy.fire_cooldown > 0.0 or to_target.length() > enemy.type.fire_range:
		return
	enemy.fire_cooldown = enemy.type.fire_interval
	pattern_fired.emit(enemy.type.shot_pattern, enemy.position, to_target.angle())


func _release(enemy: Enemy) -> void:
	enemy_vanished.emit(enemy.position, enemy.type.color, enemy.type.radius)
	enemy.deactivate()
	_free_indices.append(enemy.pool_index)


func _nearest(targets: Array[Vector2], from: Vector2) -> Vector2:
	var best := targets[0]
	for target: Vector2 in targets:
		if from.distance_squared_to(target) < from.distance_squared_to(best):
			best = target
	return best


## Push direction away from overlapping neighbours (0 when not overlapping).
func _separation(enemy: Enemy) -> Vector2:
	var push := Vector2.ZERO
	_nearby.clear()
	_grid.query(enemy.position, enemy.type.radius + MAX_ENEMY_RADIUS, _nearby)
	for index: int in _nearby:
		if index == enemy.pool_index:
			continue
		var other := _pool[index]
		if not other.active:
			continue
		var offset := enemy.position - other.position
		var min_distance := enemy.type.radius + other.type.radius
		var distance_squared := offset.length_squared()
		if distance_squared >= min_distance * min_distance:
			continue
		if distance_squared < 0.0001:
			# Exactly on top of each other: split them apart deterministically.
			offset = Vector2.from_angle(enemy.pool_index)
			distance_squared = 1.0
		var distance := sqrt(distance_squared)
		push += offset / distance * (1.0 - distance / min_distance)
	return push
