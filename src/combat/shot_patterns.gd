class_name ShotPatterns
extends RefCounted
## Bullet patterns. A shot is described by (pattern id, origin, aim angle, seed,
## fire time); every peer turns that small description into identical bullets
## with build(), so bullets themselves never need to be sent over the network.
##
## Each bullet is three numbers: angle (radians), speed (px/s), and delay (s)
## before it appears. Delays let one event describe something that unfolds over
## time, like a spiral.
##
## Ids are sent over the network: only add new patterns at the end.

enum Id { BASIC, AIMED_FAN_3, RING_24, SPIRAL, DOUBLE_SPIRAL, AIMED_FAN_7 }

const STRIDE: int = 3
const BASIC_SPREAD_DEGREES: float = 2.5
## Angle between bolts when a shot fires several (Extra Bolt upgrade).
const FAN_SPACING_DEGREES: float = 9.0
const SPIRAL_BULLETS: int = 48
const SPIRAL_INTERVAL: float = 0.05
## Radians the spiral turns per bullet.
const SPIRAL_STEP: float = TAU / 16.0


## A seed both the host and the shooting client can compute on their own.
static func make_seed(peer_id: int, input_seq: int) -> int:
	return peer_id * 1_000_003 + input_seq


## Builds every bullet of a pattern: [angle, speed, delay, angle, speed, delay, ...].
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


static func _add(out: PackedFloat32Array, angle: float, speed: float, delay: float) -> void:
	out.append(angle)
	out.append(speed)
	out.append(delay)
