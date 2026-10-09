class_name ShotPatterns
extends RefCounted
## Bullet patterns. A shot is described by (pattern id, origin, aim angle, seed).
## Every peer turns that small description into identical bullets with angles(),
## so bullets themselves never need to be sent over the network.

enum Id { BASIC }

const BASIC_SPREAD_DEGREES: float = 2.5
## Angle between bolts when a shot fires several (Extra Bolt upgrade).
const FAN_SPACING_DEGREES: float = 9.0


## A seed both the host and the shooting client can compute on their own.
static func make_seed(peer_id: int, input_seq: int) -> int:
	return peer_id * 1_000_003 + input_seq


## Direction (radians) of each bullet in the pattern. `count` bolts are fanned
## evenly around the aim, each with its own small random jitter.
static func angles(pattern: Id, aim: float, seed_value: int, count: int = 1) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var result := PackedFloat32Array()
	match pattern:
		Id.BASIC:
			for i: int in maxi(count, 1):
				var fan_offset := (i - (count - 1) / 2.0) * FAN_SPACING_DEGREES
				var jitter := rng.randf_range(-BASIC_SPREAD_DEGREES, BASIC_SPREAD_DEGREES)
				result.append(aim + deg_to_rad(fan_offset + jitter))
	return result
