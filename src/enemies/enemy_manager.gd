class_name EnemyManager
extends Node2D
## Owns a fixed pool of enemies, created once and reused (never freed mid-game).
## Host: moves them toward players, applies damage, and sends compact snapshots.
## Clients: apply those snapshots.
## All peers: keep a SpatialGrid of enemy positions for fast hit checks.

signal enemy_killed(enemy: Enemy, killer_peer_id: int, source: int)
## Every peer: a critical hit landed here (host: right away; clients: from snapshots).
signal enemy_crit(at: Vector2)
## Every peer: an enemy just disappeared here (for death effects).
signal enemy_vanished(at: Vector2, type_id: int, facing_left: bool)
## Host: a ranged enemy fired. The arena turns this into bullets + a network event.
signal pattern_fired(pattern: int, origin: Vector2, aim: float)

const ENEMY_SCENE: PackedScene = preload("res://src/enemies/enemy.tscn")
const POOL_SIZE: int = 300
const GRID_CELL_SIZE: float = 24.0
## Larger than any enemy radius; used to find touching neighbours.
const MAX_ENEMY_RADIUS: float = 24.0
## How hard overlapping enemies push each other apart.
const SEPARATION_STRENGTH: float = 40.0
## Fleeing enemies this close to a wall turn back toward the middle.
const FLEE_WALL_DISTANCE: float = 110.0
## Each enemy in a snapshot: u16 index, u8 type, u8 flags, s16 x, s16 y, u8 hp.
const SNAPSHOT_STRIDE: int = 9
const FLAG_HIT: int = 1
const FLAG_HEXED: int = 2
const FLAG_CRIT: int = 4
const FLAG_FROZEN: int = 8

## Host: total damage dealt by each peer id. Handy for tests and debugging.
var damage_by_peer: Dictionary[int, int] = {}
## Host: the part of that damage dealt to bosses.
var boss_damage_by_peer: Dictionary[int, int] = {}
## Host: damage and kills per peer per DamageSource (peer id -> {source: amount}).
var damage_by_source: Dictionary[int, Dictionary] = {}
var kills_by_source: Dictionary[int, Dictionary] = {}
var bounds: Rect2 = Rect2(-10000, -10000, 20000, 20000)
## Host: peer id -> that player's CharacterStats (or null), for upgrade damage
## bonuses. Set by the arena; without it hits deal their plain damage.
var stats_of_peer: Callable = Callable()
## Host: rolls critical hits.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _pool: Array[Enemy] = []
var _free_indices: Array[int] = []
var _grid: SpatialGrid = SpatialGrid.new(GRID_CELL_SIZE)
var _nearby: Array[int] = []


func _ready() -> void:
	rng.randomize()
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


## The closest active enemy within `max_distance` other than pool index `skip`,
## or null. Uses the grid, so it's cheap enough to call per bullet.
func find_nearest_nearby(point: Vector2, max_distance: float, skip: int = -1) -> Enemy:
	_nearby.clear()
	_grid.query(point, max_distance, _nearby)
	var best: Enemy = null
	var best_distance := max_distance * max_distance
	for index: int in _nearby:
		var enemy := _pool[index]
		if index == skip or not enemy.active:
			continue
		var distance := enemy.position.distance_squared_to(point)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## Where every active enemy is (for the minimap).
func active_positions() -> PackedVector2Array:
	var positions := PackedVector2Array()
	for enemy: Enemy in _pool:
		if enemy.active:
			positions.append(enemy.position)
	return positions


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
## `lures` are decoys (Bone Effigy): regular enemies within `lure_radius` of
## one chase it instead of the players.
## The grid is rebuilt once, at the end (it's still current from last tick; only
## this tick's new spawns are missing, which just skips their push for one tick).
func tick_host(delta: float, targets: Array[Vector2], lures: Array[Vector2] = [], lure_radius: float = 0.0) -> void:
	for enemy: Enemy in _pool:
		if not enemy.active:
			continue
		var velocity := Vector2.ZERO
		var rooted := false
		if enemy.hexed_left > 0.0:
			enemy.hexed_left = maxf(enemy.hexed_left - delta, 0.0)
			enemy.set_hexed(enemy.hexed_left > 0.0)
			if not enemy.hexed:
				enemy.hex_multiplier = 1.0
			# Bound in place: no moving or attacking (bosses only take extra damage).
			rooted = enemy.hexed and not enemy.type.is_boss
		if enemy.frozen_left > 0.0:
			enemy.frozen_left = maxf(enemy.frozen_left - delta, 0.0)
			enemy.set_frozen(enemy.frozen_left > 0.0)
			rooted = rooted or enemy.frozen
		var target_list := targets
		if not enemy.type.is_boss and not lures.is_empty():
			var lure := _nearest(lures, enemy.position)
			if lure.distance_squared_to(enemy.position) <= lure_radius * lure_radius:
				target_list = [lure]
		if not target_list.is_empty() and not rooted:
			var to_target := _nearest(target_list, enemy.position) - enemy.position
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


## The first active enemy (closest to `from`) touched by a bullet of
## `hit_radius` moving from `from` to `to`, skipping pool index `skip`, or null.
func find_hit_on_path(from: Vector2, to: Vector2, hit_radius: float, skip: int = -1) -> Enemy:
	var half := from.distance_to(to) / 2.0
	_nearby.clear()
	_grid.query((from + to) / 2.0, half + hit_radius + MAX_ENEMY_RADIUS, _nearby)
	var best: Enemy = null
	var best_along := INF
	for index: int in _nearby:
		var enemy := _pool[index]
		if index == skip or not enemy.active:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(enemy.position, from, to)
		var reach := enemy.type.radius + hit_radius
		if enemy.position.distance_squared_to(closest) > reach * reach:
			continue
		var along := from.distance_squared_to(closest)
		if along < best_along:
			best_along = along
			best = enemy
	return best


## Host: hex every active enemy within `radius` (Hex Snare).
func hex_in_radius(center: Vector2, radius: float, seconds: float, multiplier: float) -> int:
	var count := 0
	_nearby.clear()
	_grid.query(center, radius + MAX_ENEMY_RADIUS, _nearby)
	for index: int in _nearby:
		var enemy := _pool[index]
		var reach := radius + enemy.type.radius
		if enemy.active and enemy.position.distance_squared_to(center) <= reach * reach:
			enemy.hexed_left = maxf(enemy.hexed_left, seconds)
			enemy.hex_multiplier = maxf(enemy.hex_multiplier, multiplier)
			enemy.set_hexed(true)
			count += 1
	return count


## Host (Frost Hourglass): every regular enemy stops for `seconds`. Bosses keep going.
func freeze_all(seconds: float) -> void:
	for enemy: Enemy in _pool:
		if enemy.active and not enemy.type.is_boss:
			enemy.frozen_left = maxf(enemy.frozen_left, seconds)
			enemy.set_frozen(true)


## Host (Holy Bomb): damage every regular enemy within `radius`; bosses are spared.
func smite(center: Vector2, radius: float, amount: int, from_peer_id: int, source: int) -> void:
	var targets: Array[Enemy] = []
	for enemy: Enemy in _pool:
		if enemy.active and not enemy.type.is_boss and enemy.position.distance_to(center) <= radius + enemy.type.radius:
			targets.append(enemy)
	for enemy: Enemy in targets:
		if enemy.active:
			damage(enemy, amount, from_peer_id, source)


## Every active enemy touching the circle.
func enemies_in_radius(center: Vector2, radius: float) -> Array[Enemy]:
	var targets: Array[Enemy] = []
	_nearby.clear()
	_grid.query(center, radius + MAX_ENEMY_RADIUS, _nearby)
	for index: int in _nearby:
		var enemy := _pool[index]
		var reach := radius + enemy.type.radius
		if enemy.active and enemy.position.distance_squared_to(center) <= reach * reach:
			targets.append(enemy)
	return targets


## The closest active enemy within `max_distance` whose pool index isn't in
## `skip` (Chain Lightning's next jump), or null.
func find_nearest_except(point: Vector2, max_distance: float, skip: Dictionary[int, bool]) -> Enemy:
	_nearby.clear()
	_grid.query(point, max_distance, _nearby)
	var best: Enemy = null
	var best_distance := max_distance * max_distance
	for index: int in _nearby:
		var enemy := _pool[index]
		if skip.has(index) or not enemy.active:
			continue
		var distance := enemy.position.distance_squared_to(point)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## Host: damage every active enemy within `radius` (Grave Blast).
func damage_in_radius(center: Vector2, radius: float, amount: int, from_peer_id: int,
		source: int = DamageSource.ABILITY) -> void:
	for enemy: Enemy in enemies_in_radius(center, radius):
		if enemy.active:
			damage(enemy, amount, from_peer_id, source)


## Host only.
func damage(enemy: Enemy, amount: int, from_peer_id: int, source: int = DamageSource.MAIN_GUN) -> void:
	var stats: CharacterStats = stats_of_peer.call(from_peer_id) if stats_of_peer.is_valid() else null
	if stats != null:
		var crit := HitBonus.is_crit(stats, source, rng.randf()) if stats.crit_chance > 0.0 else false
		amount = HitBonus.scaled(amount, stats, enemy.type.is_boss, enemy.hp_ratio, crit)
		if crit:
			enemy.crit_since_snapshot = true
			enemy_crit.emit(enemy.position)
	if enemy.hexed:
		amount = roundi(amount * enemy.hex_multiplier)
	var dealt := mini(amount, enemy.hp)
	var died := enemy.apply_damage(amount)
	damage_by_peer[from_peer_id] = damage_by_peer.get(from_peer_id, 0) + dealt
	if enemy.type.is_boss:
		boss_damage_by_peer[from_peer_id] = boss_damage_by_peer.get(from_peer_id, 0) + dealt
	_count_source(damage_by_source, from_peer_id, source, dealt)
	if died:
		_count_source(kills_by_source, from_peer_id, source, 1)
		_release(enemy)
		enemy_killed.emit(enemy, from_peer_id, source)


func _count_source(table: Dictionary[int, Dictionary], peer_id: int, source: int, amount: int) -> void:
	if not table.has(peer_id):
		table[peer_id] = {}
	var row: Dictionary = table[peer_id]
	row[source] = int(row.get(source, 0)) + amount


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
		var flags := FLAG_HIT if enemy.hit_since_snapshot else 0
		if enemy.hexed:
			flags |= FLAG_HEXED
		if enemy.crit_since_snapshot:
			flags |= FLAG_CRIT
		if enemy.frozen:
			flags |= FLAG_FROZEN
		data.encode_u8(offset + 3, flags)
		data.encode_s16(offset + 4, clampi(roundi(enemy.position.x), -32768, 32767))
		data.encode_s16(offset + 6, clampi(roundi(enemy.position.y), -32768, 32767))
		data.encode_u8(offset + 8, roundi(enemy.hp_ratio * 255.0))
		enemy.hit_since_snapshot = false
		enemy.crit_since_snapshot = false
		offset += SNAPSHOT_STRIDE
	for peer_id: int in peer_ids:
		# The count is also what keeps the RPC valid when there are no enemies:
		# an empty byte array as the only argument arrives as "no arguments".
		_receive_snapshot.rpc_id(peer_id, count, data)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_snapshot(count: int, data: PackedByteArray) -> void:
	var t := PerfLog.start()
	_apply_snapshot(count, data)
	PerfLog.stop(&"rx_enemies", t)


func _apply_snapshot(count: int, data: PackedByteArray) -> void:
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
		var flags := data.decode_u8(offset + 3)
		if flags & FLAG_HIT:
			enemy.flash()
		if flags & FLAG_CRIT:
			enemy_crit.emit(at)
		enemy.set_hexed((flags & FLAG_HEXED) != 0)
		enemy.set_frozen((flags & FLAG_FROZEN) != 0)
		enemy.target_position = at
		var ratio := data.decode_u8(offset + 8) / 255.0
		if not is_equal_approx(ratio, enemy.hp_ratio):
			enemy.hp_ratio = ratio
			enemy.queue_redraw()
	for index: int in POOL_SIZE:
		if not seen[index] and _pool[index].active:
			var gone := _pool[index]
			enemy_vanished.emit(gone.position, gone.type_id, gone.facing_left)
			gone.deactivate()


func _desired_velocity(enemy: Enemy, to_target: Vector2, delta: float) -> Vector2:
	var direction := to_target.normalized()
	if enemy.type.flees:
		direction = _flee_direction(enemy.position, to_target)
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


## Away from the closest player, but bending back toward the middle near a wall
## so a fleeing enemy slides along it instead of getting stuck in a corner.
func _flee_direction(at: Vector2, to_target: Vector2) -> Vector2:
	var away := -to_target.normalized()
	var inner := bounds.grow(-FLEE_WALL_DISTANCE)
	if not inner.has_point(at):
		var to_middle := (bounds.get_center() - at).normalized()
		away = (away + to_middle * 1.2).normalized()
	return away


## Host: remove an enemy without a kill (a thief that got away).
func remove(enemy: Enemy) -> void:
	if enemy.active:
		_release(enemy)


func _try_fire(enemy: Enemy, to_target: Vector2, delta: float) -> void:
	if enemy.type.shot_pattern < 0:
		return
	enemy.fire_cooldown -= delta
	if enemy.fire_cooldown > 0.0 or to_target.length() > enemy.type.fire_range:
		return
	enemy.fire_cooldown = enemy.type.fire_interval
	pattern_fired.emit(enemy.type.shot_pattern, enemy.position, to_target.angle())


func _release(enemy: Enemy) -> void:
	enemy_vanished.emit(enemy.position, enemy.type_id, enemy.facing_left)
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
