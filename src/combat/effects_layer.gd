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
	queue_redraw()


func _process(delta: float) -> void:
	if _count == 0:
		return
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
	for i: int in _count:
		var fade := 1.0 - _ages[i] / _lifetimes[i]
		var size := _sizes[i] * (0.5 + 0.5 * fade)
		draw_rect(Rect2(_positions[i] - Vector2(size, size) / 2.0, Vector2(size, size)), Color(_colors[i], fade))


func _remove(index: int) -> void:
	var last := _count - 1
	_positions[index] = _positions[last]
	_velocities[index] = _velocities[last]
	_ages[index] = _ages[last]
	_lifetimes[index] = _lifetimes[last]
	_sizes[index] = _sizes[last]
	_colors[index] = _colors[last]
	_count = last
