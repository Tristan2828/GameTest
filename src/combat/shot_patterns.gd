class_name ShotPatterns
extends RefCounted
## Bullet patterns. A shot is described by (pattern id, origin, aim angle, seed).
## Every peer turns that small description into identical bullets with angles(),
## so bullets themselves never need to be sent over the network.

enum Id { BASIC }

const BASIC_SPREAD_DEGREES: float = 2.5


## A seed both the host and the shooting client can compute on their own.
static func make_seed(peer_id: int, input_seq: int) -> int:
	return peer_id * 1_000_003 + input_seq


## Direction (radians) of each bullet in the pattern.
static func angles(pattern: Id, aim: float, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var result := PackedFloat32Array()
	match pattern:
		Id.BASIC:
			result.append(aim + deg_to_rad(rng.randf_range(-BASIC_SPREAD_DEGREES, BASIC_SPREAD_DEGREES)))
	return result
