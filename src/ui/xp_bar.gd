class_name XpBar
extends Control
## Thin team XP bar across the top of the screen.

const BACK_COLOR: Color = Color(0.08, 0.06, 0.12, 0.85)
const FILL_COLOR: Color = Color(0.35, 0.75, 1.0)
const EDGE_COLOR: Color = Color(0.45, 0.4, 0.6)

var ratio: float = 0.0


func set_ratio(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, ratio):
		return
	ratio = clamped
	queue_redraw()


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, BACK_COLOR)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * ratio, size.y)), FILL_COLOR)
	draw_rect(area, EDGE_COLOR, false, 1.0)
