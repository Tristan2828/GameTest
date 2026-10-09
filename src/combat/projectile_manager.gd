class_name ProjectileManager
extends Node2D
## Holds every bullet in flat arrays instead of one node per bullet. That's far
## cheaper with hundreds of bullets, and the arrays are allocated once up front,
## so bullets are pooled for free.
##
## A bullet's position is origin + velocity * age, so any peer that spawns the
## same bullet gets the same path.
##
## A bullet with negative age hasn't appeared yet (patterns like spirals spawn
## all their bullets at once with staggered delays).
##
## Two instances exist: player bullets (hit enemies) and enemy bullets (hit
## players). Only the host's bullets deal damage. Clients' bullets are visual:
## they vanish on contact, but the host decides the actual hits.

const CAPACITY: int = 4096

## A bullet hit something here (for sparks). Emitted on every peer.
signal hit_at(at: Vector2)

@export var hit_radius: float = 2.0
@export var glow_radius: float = 3.0
@export var core_radius: float = 1.5
@export var glow_color: Color = Color(1.0, 0.75, 0.3, 0.45)
@export var core_color: Color = Color(1.0, 0.97, 0.8)

## Bullets outside this rectangle are removed.
var bounds: Rect2 = Rect2(-10000, -10000, 20000, 20000)

var _count: int = 0
var _origins: PackedVector2Array = PackedVector2Array()
var _velocities: PackedVector2Array = PackedVector2Array()
var _ages: PackedFloat32Array = PackedFloat32Array()
var _lifetimes: PackedFloat32Array = PackedFloat32Array()
var _damages: PackedInt32Array = PackedInt32Array()
var _owners: PackedInt32Array = PackedInt32Array()
## Enemies each bullet can still pass through.
var _pierce: PackedInt32Array = PackedInt32Array()
## Pool index of the enemy last hit, so a piercing bullet doesn't hit it again next tick.
var _last_hit: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_origins.resize(CAPACITY)
	_velocities.resize(CAPACITY)
	_ages.resize(CAPACITY)
	_lifetimes.resize(CAPACITY)
	_damages.resize(CAPACITY)
	_owners.resize(CAPACITY)
	_pierce.resize(CAPACITY)
	_last_hit.resize(CAPACITY)


## Returns false if the pool is full.
## `start_age` < 0 delays the bullet; > 0 starts it partway along its path.
func spawn(origin: Vector2, velocity: Vector2, damage: int, lifetime: float, owner_peer_id: int,
		pierce: int = 0, start_age: float = 0.0) -> bool:
	if _count >= CAPACITY:
		return false
	_origins[_count] = origin
	_velocities[_count] = velocity
	_ages[_count] = start_age
	_lifetimes[_count] = lifetime
	_damages[_count] = damage
	_owners[_count] = owner_peer_id
	_pierce[_count] = pierce
	_last_hit[_count] = -1
	_count += 1
	return true


func count() -> int:
	return _count


func position_of(index: int) -> Vector2:
	return _origins[index] + _velocities[index] * _ages[index]


func clear() -> void:
	_count = 0
	queue_redraw()


## Ages every bullet and removes expired or out-of-bounds ones.
func step(delta: float) -> void:
	var i := 0
	while i < _count:
		_ages[i] += delta
		if _ages[i] < 0.0:
			i += 1
		elif _ages[i] >= _lifetimes[i] or not bounds.has_point(position_of(i)):
			_remove(i)
		else:
			i += 1
	queue_redraw()


## Removes bullets touching an enemy (or uses up one pierce). With `apply_damage`
## (host only) they also hurt it.
func resolve_hits(enemies: EnemyManager, apply_damage: bool) -> void:
	var i := 0
	while i < _count:
		if _ages[i] < 0.0:
			i += 1
			continue
		var enemy := enemies.find_hit(position_of(i), hit_radius)
		if enemy == null or enemy.pool_index == _last_hit[i]:
			i += 1
			continue
		hit_at.emit(position_of(i))
		if apply_damage:
			enemies.damage(enemy, _damages[i], _owners[i])
		if _pierce[i] > 0:
			_pierce[i] -= 1
			_last_hit[i] = enemy.pool_index
			i += 1
		else:
			_remove(i)


## Enemy bullets vs players. Bullets pass through players who can't be hit right
## now (dashing, invulnerable, downed). Host: hits cost hearts. Clients: the
## bullet just vanishes; hearts arrive in the next snapshot.
func resolve_player_hits(players: Array[Player], is_host: bool) -> void:
	var i := 0
	while i < _count:
		if _ages[i] < 0.0:
			i += 1
			continue
		var point := position_of(i)
		var hit_player: Player = null
		for player: Player in players:
			var reach := player.stats.hitbox_radius + hit_radius
			if player.world_position().distance_squared_to(point) <= reach * reach and player.can_be_hit():
				hit_player = player
				break
		if hit_player == null:
			i += 1
			continue
		if is_host:
			hit_player.take_hit(_damages[i])
		_remove(i)


## Removes every bullet within `radius` of `center` (Grave Blast). Returns how many.
func clear_near(center: Vector2, radius: float) -> int:
	var removed := 0
	var i := 0
	while i < _count:
		if position_of(i).distance_squared_to(center) <= radius * radius:
			_remove(i)
			removed += 1
		else:
			i += 1
	queue_redraw()
	return removed


func _draw() -> void:
	for i: int in _count:
		if _ages[i] < 0.0:
			continue
		var point := position_of(i)
		draw_circle(point, glow_radius, glow_color)
		draw_circle(point, core_radius, core_color)


## Order doesn't matter, so fill the gap with the last bullet.
func _remove(index: int) -> void:
	var last := _count - 1
	_origins[index] = _origins[last]
	_velocities[index] = _velocities[last]
	_ages[index] = _ages[last]
	_lifetimes[index] = _lifetimes[last]
	_damages[index] = _damages[last]
	_owners[index] = _owners[last]
	_pierce[index] = _pierce[last]
	_last_hit[index] = _last_hit[last]
	_count = last
