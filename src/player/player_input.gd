class_name PlayerInput
extends RefCounted
## One physics tick of player input. Clients send these to the host.

## Increases by 1 every tick. The host echoes back the last one it simulated,
## which lets the client check its prediction.
var seq: int = 0
## Movement direction, length 0..1.
var move: Vector2 = Vector2.ZERO
## Aim angle in radians.
var aim: float = 0.0
var fire: bool = false
## Total dash presses so far. A counter (not a "pressed this tick" flag) means a
## lost network packet can never swallow a dash press.
var dash_count: int = 0
