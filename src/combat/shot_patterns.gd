class_name ShotPatterns
extends RefCounted
## Bullet patterns. A shot is described by (pattern id, origin, aim angle, seed,
## fire time); every peer turns that small description into identical bullets
## with build(), so bullets themselves never need to be sent over the network.
##
## Each bullet is five numbers: angle (radians), speed (px/s), delay (s) before
## it appears, and a spawn offset (x, y) from the origin. Delays let one event
## describe something that unfolds over time (spirals); offsets let it describe
## shapes that don't start from a single point (walls).
##
## Ids are sent over the network: only add new patterns at the end.

enum Id {
	BASIC, AIMED_FAN_3, RING_24, SPIRAL, DOUBLE_SPIRAL, AIMED_FAN_7,
	RING_8, WALL, RANDOM_SPRAY, CROSS, AIMED_LINE_5, BURST_12, SHOTGUN,
}

const STRIDE: int = 5
const BASIC_SPREAD_DEGREES: float = 2.5
## Angle between bolts when a shot fires several (Extra Bolt upgrade).
const FAN_SPACING_DEGREES: float = 9.0
const SPIRAL_BULLETS: int = 48
const SPIRAL_INTERVAL: float = 0.05
## Radians the spiral turns per bullet.
const SPIRAL_STEP: float = TAU / 16.0
const WALL_BULLETS: int = 22
const WALL_SPACING: float = 12.0
const WALL_GAP: int = 3
const SHOTGUN_SPACING_DEGREES: float = 7.0


## A seed both the host and the shooting client can compute on their own.
static func make_seed(peer_id: int, input_seq: int) -> int:
	return peer_id * 1_000_003 + input_seq


## Builds every bullet of a pattern: [angle, speed, delay, offset_x, offset_y, ...].
## `count` and `base_speed` are used by the player's pattern (upgrades change them).
static func build(pattern: Id, aim: float, seed_value: int, count: int = 1, base_speed: float = 0.0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	match pattern:
		Id.BASIC:
			for i: int in maxi(count, 1):
				var fan_offset := (i - (count - 1) / 2.0) * FAN_SPACING_DEGREES
				var jitter := rng.randf_range(-BASIC_SPREAD_DEGREES, BASIC_SPREAD_DEGREES)
				_add(out, aim + deg_to_rad(fan_offset + jitter), base_speed, 0.0)
		Id.AIMED_FAN_3:
			_fan(out, aim, 3, deg_to_rad(12.0), 105.0)
		Id.AIMED_FAN_7:
			_fan(out, aim, 7, deg_to_rad(10.0), 130.0)
		Id.RING_24:
			var rotation := rng.randf() * TAU
			for i: int in 24:
				_add(out, rotation + TAU * i / 24.0, 90.0, 0.0)
		Id.SPIRAL, Id.DOUBLE_SPIRAL:
			var arms := 2 if pattern == Id.DOUBLE_SPIRAL else 1
			var rotation := rng.randf() * TAU
			var direction := 1.0 if rng.randf() < 0.5 else -1.0
			for i: int in SPIRAL_BULLETS:
				for arm: int in arms:
					var angle := rotation + direction * i * SPIRAL_STEP + PI * arm
					_add(out, angle, 100.0, i * SPIRAL_INTERVAL)
		Id.RING_8:
			var rotation := rng.randf() * TAU
			for i: int in 8:
				_add(out, rotation + TAU * i / 8.0, 65.0, 0.0)
		Id.WALL:
			# A line of bullets across the aim direction, marching forward, with a
			# gap somewhere to slip through.
			var across := Vector2.from_angle(aim + PI / 2.0)
			var gap := rng.randi_range(3, WALL_BULLETS - 6)
			for i: int in WALL_BULLETS:
				if i >= gap and i < gap + WALL_GAP:
					continue
				var offset := across * (i - (WALL_BULLETS - 1) / 2.0) * WALL_SPACING
				_add(out, aim, 85.0, 0.0, offset)
		Id.RANDOM_SPRAY:
			for i: int in 30:
				var angle := aim + deg_to_rad(rng.randf_range(-50.0, 50.0))
				_add(out, angle, rng.randf_range(70.0, 140.0), rng.randf_range(0.0, 0.6))
		Id.CROSS:
			for arm: int in 4:
				for i: int in 6:
					_add(out, aim + PI / 2.0 * arm, 70.0 + i * 15.0, 0.0)
		Id.AIMED_LINE_5:
			for i: int in 5:
				_add(out, aim, 90.0 + i * 20.0, 0.0)
		Id.BURST_12:
			for wave: int in 3:
				for i: int in 12:
					_add(out, aim + TAU * i / 12.0 + wave * PI / 12.0, 150.0, wave * 0.15)
		Id.SHOTGUN:
			# Player pellets: a wide fan with uneven speeds. Extra Bolt adds 2 pellets.
			var pellets := 5 + (maxi(count, 1) - 1) * 2
			for i: int in pellets:
				var spread := (i - (pellets - 1) / 2.0) * SHOTGUN_SPACING_DEGREES
				var jitter := rng.randf_range(-2.0, 2.0)
				_add(out, aim + deg_to_rad(spread + jitter), base_speed * rng.randf_range(0.85, 1.1), 0.0)
	return out


## Just the angles (handy for tests and simple callers).
static func angles(pattern: Id, aim: float, seed_value: int, count: int = 1) -> PackedFloat32Array:
	var bullets := build(pattern, aim, seed_value, count)
	var result := PackedFloat32Array()
	for i: int in range(0, bullets.size(), STRIDE):
		result.append(bullets[i])
	return result


static func _fan(out: PackedFloat32Array, aim: float, count: int, spacing: float, speed: float) -> void:
	for i: int in count:
		_add(out, aim + (i - (count - 1) / 2.0) * spacing, speed, 0.0)


static func _add(out: PackedFloat32Array, angle: float, speed: float, delay: float, offset: Vector2 = Vector2.ZERO) -> void:
	out.append(angle)
	out.append(speed)
	out.append(delay)
	out.append(offset.x)
	out.append(offset.y)
