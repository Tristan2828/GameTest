class_name HeartsDisplay
extends Control
## Draws the local player's hearts as simple pixel hearts.

const HEART_COLOR: Color = Color(0.9, 0.2, 0.3)
const EMPTY_COLOR: Color = Color(0.25, 0.15, 0.18)
const OUTLINE_COLOR: Color = Color(0.05, 0.03, 0.05)
const HEART_SPACING: float = 12.0

## Each row of the heart shape, as (x offset, width) in pixels; 9 px wide, 8 tall.
const SHAPE: Array[Vector2i] = [
	Vector2i(1, 3), Vector2i(0, 9), Vector2i(0, 9), Vector2i(0, 9),
	Vector2i(1, 7), Vector2i(2, 5), Vector2i(3, 3), Vector2i(4, 1),
]

var hearts: int = 0
var max_hearts: int = 0


func set_hearts(current: int, maximum: int) -> void:
	if current == hearts and maximum == max_hearts:
		return
	hearts = current
	max_hearts = maximum
	queue_redraw()


func _draw() -> void:
	for i: int in max_hearts:
		var origin := Vector2(i * HEART_SPACING, 0)
		var color := HEART_COLOR if i < hearts else EMPTY_COLOR
		for row: int in SHAPE.size():
			var span: Vector2i = SHAPE[row]
			draw_rect(Rect2(origin + Vector2(span.x - 1, row), Vector2(span.y + 2, 1)), OUTLINE_COLOR)
		for row: int in SHAPE.size():
			var span: Vector2i = SHAPE[row]
			draw_rect(Rect2(origin + Vector2(span.x, row), Vector2(span.y, 1)), color)
