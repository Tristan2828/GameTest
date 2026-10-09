class_name GemManager
extends Node2D
## XP gems, stored in flat arrays like bullets (a fixed pool, no node per gem).
##
## Host: spawns gems when enemies die, decides who collects them, and tells
## clients about spawns and pickups (batched, reliable, once per tick).
## Everyone: pulls gems toward the nearest player in range (the "magnet"), so
## the pull looks right on every screen. Only the host's pickups count.

signal collected(value: int, collector_peer_id: int)

const CAPACITY: int = 400
const COLLECT_RADIUS: float = 6.0
const PULL_ACCELERATION: float = 900.0
const MAX_PULL_SPEED: float = 420.0
const SMALL_COLOR: Color = Color(0.35, 0.75, 1.0)
const BIG_COLOR: Color = Color(0.45, 1.0, 0.55)
const OUTLINE_COLOR: Color = Color(0.05, 0.08, 0.15)

var _active: PackedByteArray = PackedByteArray()
var _positions: PackedVector2Array = PackedVector2Array()
var _values: PackedInt32Array = PackedInt32Array()
var _speeds: PackedFloat32Array = PackedFloat32Array()
## Peer id of the player a gem is flying toward (0 = resting).
var _targets: PackedInt32Array = PackedInt32Array()
var _free: Array[int] = []
var _count: int = 0

# Host: events gathered during this tick, sent by flush_events().
var _new_ids: PackedInt32Array = PackedInt32Array()
var _new_positions: PackedVector2Array = PackedVector2Array()
var _new_values: PackedInt32Array = PackedInt32Array()
var _collected_ids: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_active.resize(CAPACITY)
	_positions.resize(CAPACITY)
	_values.resize(CAPACITY)
	_speeds.resize(CAPACITY)
	_targets.resize(CAPACITY)
	for i: int in range(CAPACITY - 1, -1, -1):
		_free.append(i)


func _ready() -> void:
	add_to_group("gems")


func count() -> int:
	return _count


## Position of the closest gem, or Vector2.INF if there are none.
func nearest_gem(from: Vector2) -> Vector2:
	var best := Vector2.INF
	for id: int in CAPACITY:
		if _active[id] != 0 and (best == Vector2.INF or from.distance_squared_to(_positions[id]) < from.distance_squared_to(best)):
			best = _positions[id]
	return best


## Host: returns false if the pool is full (the caller should add the XP directly).
func spawn_host(at: Vector2, value: int) -> bool:
	if _free.is_empty():
		return false
	var id: int = _free.pop_back()
	_activate(id, at, value)
	_new_ids.append(id)
	_new_positions.append(at)
	_new_values.append(value)
	return true


## Moves pulled gems. `player_positions` maps peer id -> position of each
## player who can collect (alive), and `pickup_radii` maps peer id -> radius.
func tick(delta: float, player_positions: Dictionary[int, Vector2], pickup_radii: Dictionary[int, float], is_host: bool) -> void:
	if _count == 0:
		return
	for id: int in CAPACITY:
		if _active[id] == 0:
			continue
		var target_id := _targets[id]
		if target_id != 0 and not player_positions.has(target_id):
			target_id = 0
			_speeds[id] = 0.0
		if target_id == 0:
			target_id = _find_collector(_positions[id], player_positions, pickup_radii)
		_targets[id] = target_id
		if target_id == 0:
			continue
		var destination: Vector2 = player_positions[target_id]
		_speeds[id] = minf(_speeds[id] + PULL_ACCELERATION * delta, MAX_PULL_SPEED)
		_positions[id] = _positions[id].move_toward(destination, _speeds[id] * delta)
		if is_host and _positions[id].distance_to(destination) <= COLLECT_RADIUS:
			var value := _values[id]
			_release(id)
			_collected_ids.append(id)
			collected.emit(value, target_id)
	queue_redraw()


## Host: send this tick's spawn and pickup events to the given peers.
func flush_events(peer_ids: Array[int]) -> void:
	if not _new_ids.is_empty():
		for peer_id: int in peer_ids:
			_receive_spawns.rpc_id(peer_id, _new_ids, _new_positions, _new_values)
		_new_ids.clear()
		_new_positions.clear()
		_new_values.clear()
	if not _collected_ids.is_empty():
		for peer_id: int in peer_ids:
			_receive_collected.rpc_id(peer_id, _collected_ids.size(), _collected_ids)
		_collected_ids.clear()


## Host: give a newly joined peer every gem currently on the ground.
func send_full_state(peer_id: int) -> void:
	var ids := PackedInt32Array()
	var positions := PackedVector2Array()
	var values := PackedInt32Array()
	for id: int in CAPACITY:
		if _active[id] != 0:
			ids.append(id)
			positions.append(_positions[id])
			values.append(_values[id])
	if not ids.is_empty():
		_receive_spawns.rpc_id(peer_id, ids, positions, values)


func clear() -> void:
	for id: int in CAPACITY:
		if _active[id] != 0:
			_release(id)
	_new_ids.clear()
	_new_positions.clear()
	_new_values.clear()
	_collected_ids.clear()
	queue_redraw()


func _draw() -> void:
	for id: int in CAPACITY:
		if _active[id] == 0:
			continue
		var size := 3.0 if _values[id] >= 5 else 2.0
		var center := _positions[id].round()
		var outline := PackedVector2Array([
			center + Vector2(0, -size - 1), center + Vector2(size + 1, 0),
			center + Vector2(0, size + 1), center + Vector2(-size - 1, 0)])
		var diamond := PackedVector2Array([
			center + Vector2(0, -size), center + Vector2(size, 0),
			center + Vector2(0, size), center + Vector2(-size, 0)])
		draw_colored_polygon(outline, OUTLINE_COLOR)
		draw_colored_polygon(diamond, BIG_COLOR if _values[id] >= 5 else SMALL_COLOR)


func _find_collector(at: Vector2, player_positions: Dictionary[int, Vector2], pickup_radii: Dictionary[int, float]) -> int:
	var best_id := 0
	var best_distance := INF
	for peer_id: int in player_positions:
		var distance := at.distance_to(player_positions[peer_id])
		if distance <= pickup_radii.get(peer_id, 0.0) and distance < best_distance:
			best_id = peer_id
			best_distance = distance
	return best_id


func _activate(id: int, at: Vector2, value: int) -> void:
	if _active[id] == 0:
		_count += 1
	_active[id] = 1
	_positions[id] = at
	_values[id] = value
	_speeds[id] = 0.0
	_targets[id] = 0
	queue_redraw()


func _release(id: int) -> void:
	if _active[id] == 0:
		return
	_active[id] = 0
	_count -= 1
	if not _free.has(id):
		_free.append(id)
	queue_redraw()


@rpc("authority", "call_remote", "reliable")
func _receive_spawns(ids: PackedInt32Array, positions: PackedVector2Array, values: PackedInt32Array) -> void:
	for i: int in ids.size():
		if ids[i] >= 0 and ids[i] < CAPACITY:
			_activate(ids[i], positions[i], values[i])


@rpc("authority", "call_remote", "reliable")
func _receive_collected(_count_hint: int, ids: PackedInt32Array) -> void:
	for id: int in ids:
		if id >= 0 and id < CAPACITY:
			_release(id)
