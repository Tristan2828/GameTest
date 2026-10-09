class_name BombBlast
extends Node2D
## Purely visual: an expanding, fading ring where a bomb went off.

const DURATION: float = 0.45
const COLOR: Color = Color(0.85, 0.75, 1.0)

var radius: float = 200.0

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _time / DURATION
	var ring_radius := radius * (1.0 - pow(1.0 - t, 3.0))
	var faded := Color(COLOR, 1.0 - t)
	draw_circle(Vector2.ZERO, ring_radius, Color(COLOR, 0.15 * (1.0 - t)))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, faded, 3.0)
