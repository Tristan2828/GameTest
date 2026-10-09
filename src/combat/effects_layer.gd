class_name EffectsLayer
extends Node2D
## Purely visual particles (hit sparks, death puffs, bomb flashes), stored in
## flat arrays like bullets. Every peer spawns its own from events it already
## sees, so nothing here is ever sent over the network.

const CAPACITY: int = 2000

var _count: int = 0
var _positions: PackedVector2Array = PackedVector2Array()
var _velocities: PackedVector2Array = PackedVector2Array()
var _ages: PackedFloat32Array = PackedFloat32Array()
var _lifetimes: PackedFloat32Array = PackedFloat32Array()
var _sizes: PackedFloat32Array = PackedFloat32Array()
var _colors: PackedColorArray = PackedColorArray()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Dying enemies: [sprite, position, flip, scale, age, duration]. Few at once.
var _corpses: Array[Array] = []

const MAX_CORPSES: int = 120


func _init() -> void:
	# Resize each one directly: packed arrays are copied when put in a list.
	_positions.resize(CAPACITY)
	_velocities.resize(CAPACITY)
	_ages.resize(CAPACITY)
	_lifetimes.resize(CAPACITY)
	_sizes.resize(CAPACITY)
	_colors.resize(CAPACITY)
	_rng.randomize()


func count() -> int:
	return _count


func corpse_count() -> int:
	return _corpses.size()


## A sprite that flashes, squashes into the ground and fades (death animation).
func corpse(sprite: String, at: Vector2, flip: bool, scale: float, duration: float) -> void:
	if _corpses.size() >= MAX_CORPSES:
		_corpses.pop_front()
	_corpses.append([sprite, at, flip, scale, 0.0, duration])


## A ring of particles flying outward.
func burst(at: Vector2, color: Color, amount: int, speed: float, lifetime: float, size: float = 1.5) -> void:
	for i: int in amount:
		if _count >= CAPACITY:
			return
		var direction := Vector2.from_angle(_rng.randf() * TAU)
		_positions[_count] = at
		_velocities[_count] = direction * speed * _rng.randf_range(0.4, 1.0)
		_ages[_count] = 0.0
		_lifetimes[_count] = lifetime * _rng.randf_range(0.6, 1.0)
		_sizes[_count] = size
		_colors[_count] = color
		_count += 1


func clear() -> void:
	_count = 0
	_corpses.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _count == 0 and _corpses.is_empty():
		return
	for corpse_data: Array in _corpses:
		corpse_data[4] += delta
	_corpses = _corpses.filter(func(corpse_data: Array) -> bool: return corpse_data[4] < corpse_data[5])
	var i := 0
	while i < _count:
		_ages[i] += delta
		if _ages[i] >= _lifetimes[i]:
			_remove(i)
			continue
		_positions[i] += _velocities[i] * delta
		_velocities[i] *= 1.0 - minf(6.0 * delta, 1.0)
		i += 1
	queue_redraw()


func _draw() -> void:
	for corpse_data: Array in _corpses:
		_draw_corpse(corpse_data)
	for i: int in _count:
		var fade := 1.0 - _ages[i] / _lifetimes[i]
		var size := _sizes[i] * (0.5 + 0.5 * fade)
		draw_rect(Rect2(_positions[i] - Vector2(size, size) / 2.0, Vector2(size, size)), Color(_colors[i], fade))


func _draw_corpse(corpse_data: Array) -> void:
	var sprite: String = corpse_data[0]
	var at: Vector2 = corpse_data[1]
	var t: float = corpse_data[4] / corpse_data[5]
	var texture := PixelArt.texture(sprite, Color.WHITE, t < 0.15)
	var base := Vector2(texture.get_size()) * float(corpse_data[3])
	# Squash down into the ground and spread a little wider, fading out.
	var size := Vector2(base.x * (1.0 + 0.5 * t), base.y * (1.0 - 0.85 * t))
	var rect := Rect2((at + Vector2(-size.x / 2.0, base.y / 2.0 - size.y)).round(), size)
	PixelArt.draw_rect_flipped(self, texture, rect, corpse_data[2], Color(1, 1, 1, 1.0 - t * t))


func _remove(index: int) -> void:
	var last := _count - 1
	_positions[index] = _positions[last]
	_velocities[index] = _velocities[last]
	_ages[index] = _ages[last]
	_lifetimes[index] = _lifetimes[last]
	_sizes[index] = _sizes[last]
	_colors[index] = _colors[last]
	_count = last
