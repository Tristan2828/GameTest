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
## Ricochet: how far a bouncing bolt looks for its next enemy.
const RICOCHET_RANGE: float = 110.0
## Homing bolts only steer toward enemies this close.
const HOMING_RANGE: float = 130.0

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
## DamageSource of each bullet (main gun or Seeking Bolts), for the run's weapon breakdown.
var _sources: PackedByteArray = PackedByteArray()
## Enemies each bullet can still pass through.
var _pierce: PackedInt32Array = PackedInt32Array()
## Pool index of the enemy last hit, so a piercing bullet doesn't hit it again next tick.
var _last_hit: PackedInt32Array = PackedInt32Array()
## Times each bullet can still bounce to another enemy (Ricochet).
var _bounces: PackedInt32Array = PackedInt32Array()
## How fast each bullet turns toward enemies, radians per second (Hunting Bolts).
var _homing: PackedFloat32Array = PackedFloat32Array()
## True once any homing bullet was spawned, so steer() costs nothing without them.
var _any_homing: bool = false


func _init() -> void:
	_origins.resize(CAPACITY)
	_velocities.resize(CAPACITY)
	_ages.resize(CAPACITY)
	_lifetimes.resize(CAPACITY)
	_damages.resize(CAPACITY)
	_owners.resize(CAPACITY)
	_sources.resize(CAPACITY)
	_pierce.resize(CAPACITY)
	_last_hit.resize(CAPACITY)
	_bounces.resize(CAPACITY)
	_homing.resize(CAPACITY)


## Returns false if the pool is full.
## `start_age` < 0 delays the bullet; > 0 starts it partway along its path.
func spawn(origin: Vector2, velocity: Vector2, damage: int, lifetime: float, owner_peer_id: int,
		pierce: int = 0, start_age: float = 0.0, source: int = DamageSource.MAIN_GUN,
		bounces: int = 0, homing: float = 0.0) -> bool:
	if _count >= CAPACITY:
		return false
	_origins[_count] = origin
	_velocities[_count] = velocity
	_ages[_count] = start_age
	_lifetimes[_count] = lifetime
	_damages[_count] = damage
	_owners[_count] = owner_peer_id
	_sources[_count] = source
	_pierce[_count] = pierce
	_last_hit[_count] = -1
	_bounces[_count] = bounces
	_homing[_count] = homing
	_any_homing = _any_homing or homing > 0.0
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


## Turns homing bullets toward the nearest enemy. Every peer runs it with the
## enemies it knows about (clients' bullets are only visual anyway). Velocity
## changes, so the origin is moved to keep position = origin + velocity * age.
func steer(enemies: EnemyManager, delta: float) -> void:
	if not _any_homing:
		return
	var any_left := false
	for i: int in _count:
		if _homing[i] <= 0.0:
			continue
		any_left = true
		if _ages[i] < 0.0:
			continue
		var point := position_of(i)
		var target := enemies.find_nearest_nearby(point, HOMING_RANGE, _last_hit[i])
		if target == null:
			continue
		var max_turn := _homing[i] * delta
		var turn := clampf(angle_difference(_velocities[i].angle(), (target.position - point).angle()), -max_turn, max_turn)
		_velocities[i] = _velocities[i].rotated(turn)
		_origins[i] = point - _velocities[i] * _ages[i]
	_any_homing = any_left


## Removes bullets touching an enemy (or uses up one pierce, or bounces). With `apply_damage`
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
			enemies.damage(enemy, _damages[i], _owners[i], _sources[i])
		if _pierce[i] > 0:
			_pierce[i] -= 1
			_last_hit[i] = enemy.pool_index
			i += 1
		elif _bounces[i] > 0 and _bounce(i, enemies, enemy):
			i += 1
		else:
			_remove(i)


## Ricochet: aim bullet `i` at the closest other enemy near `hit`. Returns
## false if there is none (the bullet is used up then).
func _bounce(i: int, enemies: EnemyManager, hit: Enemy) -> bool:
	var point := position_of(i)
	var next := enemies.find_nearest_nearby(point, RICOCHET_RANGE, hit.pool_index)
	if next == null:
		return false
	_bounces[i] -= 1
	_last_hit[i] = hit.pool_index
	# Restart the path from here, with a fresh stretch of flight.
	_velocities[i] = (next.position - point).normalized() * _velocities[i].length()
	_origins[i] = point
	_lifetimes[i] = maxf(_lifetimes[i] - _ages[i], RICOCHET_RANGE / maxf(_velocities[i].length(), 1.0))
	_ages[i] = 0.0
	return true


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


## One baked glow+core texture per bullet (batched into a single draw call);
## bullets off screen are skipped. Bullets live up to 7s in an arena much bigger
## than the screen, so most of them usually are.
func _draw() -> void:
	var texture := PixelArt.disc_texture(glow_radius, glow_color, core_radius, core_color)
	var half := Vector2(texture.get_size()) / 2.0
	var view := PixelArt.visible_rect(self)
	for i: int in _count:
		if _ages[i] < 0.0:
			continue
		var point := position_of(i)
		if view.has_point(point):
			draw_texture(texture, point - half)


## Order doesn't matter, so fill the gap with the last bullet.
func _remove(index: int) -> void:
	var last := _count - 1
	_origins[index] = _origins[last]
	_velocities[index] = _velocities[last]
	_ages[index] = _ages[last]
	_lifetimes[index] = _lifetimes[last]
	_damages[index] = _damages[last]
	_owners[index] = _owners[last]
	_sources[index] = _sources[last]
	_pierce[index] = _pierce[last]
	_last_hit[index] = _last_hit[last]
	_bounces[index] = _bounces[last]
	_homing[index] = _homing[last]
	_count = last
