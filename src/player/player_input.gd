class_name PlayerInput
extends RefCounted
## One physics tick of player input. Clients send these to the host.

## Increases by 1 every tick. The host echoes back the last one it simulated,
## which lets the client check its prediction.
var seq: int = 0
## Movement direction, length 0..1.
var move: Vector2 = Vector2.ZERO
## Where the main weapon attacks, in radians. Nobody aims by hand: AutoAim picks
## it on the player's own computer from what that screen shows.
var aim: float = 0.0
## True when AutoAim found something to attack.
var fire: bool = false
