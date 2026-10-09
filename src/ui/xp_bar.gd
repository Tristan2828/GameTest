class_name XpBar
extends Control
## Thin team XP bar across the top of the screen.

## Also used for the boss health bar (with a different fill color).
@export var fill_color: Color = Color(0.35, 0.75, 1.0)
@export var back_color: Color = Color(0.08, 0.06, 0.12, 0.85)
@export var edge_color: Color = Color(0.45, 0.4, 0.6)

var ratio: float = 0.0


func set_ratio(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, ratio):
		return
	ratio = clamped
	queue_redraw()


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, back_color)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * ratio, size.y)), fill_color)
	draw_rect(area, edge_color, false, 1.0)
