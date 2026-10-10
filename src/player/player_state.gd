class_name PlayerState
extends RefCounted
## Everything the player simulation remembers between ticks.

var position: Vector2 = Vector2.ZERO
var aim: float = 0.0
## The way the player last moved (host: Spirit Daggers fly this way).
var facing: float = 0.0
var fire_cooldown_left: float = 0.0
