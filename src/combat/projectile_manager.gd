class_name ProjectileManager
extends Node2D
## Holds every bullet in flat arrays instead of one node per bullet. That's far
## cheaper with hundreds of bullets, and the arrays are allocated once up front,
## so bullets are pooled for free.
##
## A bullet's position is origin + velocity * age, so any peer that spawns the
## same bullet gets the same path.
##
## Only the host's bullets deal damage. Clients' bullets are visual: they vanish
## when they touch an enemy, but the host decides the actual hits.

const CAPACITY: int = 4096
const HIT_RADIUS: float = 2.0
const GLOW_COLOR: Color = Color(1.0, 0.75, 0.3, 0.45)
const CORE_COLOR: Color = Color(1.0, 0.97, 0.8)

## Bullets outside this rectangle are removed.
var bounds: Rect2 = Rect2(-10000, -10000, 20000, 20000)

var _count: int = 0
var _origins: PackedVector2Array = PackedVector2Array()
var _velocities: PackedVector2Array = PackedVector2Array()
var _ages: PackedFloat32Array = PackedFloat32Array()
var _lifetimes: PackedFloat32Array = PackedFloat32Array()
var _damages: PackedInt32Array = PackedInt32Array()
var _owners: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_origins.resize(CAPACITY)
	_velocities.resize(CAPACITY)
	_ages.resize(CAPACITY)
	_lifetimes.resize(CAPACITY)
	_damages.resize(CAPACITY)
	_owners.resize(CAPACITY)


## Returns false if the pool is full.
func spawn(origin: Vector2, velocity: Vector2, damage: int, lifetime: float, owner_peer_id: int) -> bool:
	if _count >= CAPACITY:
		return false
	_origins[_count] = origin
	_velocities[_count] = velocity
	_ages[_count] = 0.0
	_lifetimes[_count] = lifetime
	_damages[_count] = damage
	_owners[_count] = owner_peer_id
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
		if _ages[i] >= _lifetimes[i] or not bounds.has_point(position_of(i)):
			_remove(i)
		else:
			i += 1
	queue_redraw()


## Removes bullets touching an enemy. With `apply_damage` (host only) they also hurt it.
func resolve_hits(enemies: EnemyManager, apply_damage: bool) -> void:
	var i := 0
	while i < _count:
		var enemy := enemies.find_hit(position_of(i), HIT_RADIUS)
		if enemy == null:
			i += 1
			continue
		if apply_damage:
			enemies.damage(enemy, _damages[i], _owners[i])
		_remove(i)


func _draw() -> void:
	for i: int in _count:
		var point := position_of(i)
		draw_circle(point, 3.0, GLOW_COLOR)
		draw_circle(point, 1.5, CORE_COLOR)


## Order doesn't matter, so fill the gap with the last bullet.
func _remove(index: int) -> void:
	var last := _count - 1
	_origins[index] = _origins[last]
	_velocities[index] = _velocities[last]
	_ages[index] = _ages[last]
	_lifetimes[index] = _lifetimes[last]
	_damages[index] = _damages[last]
	_owners[index] = _owners[last]
	_count = last
