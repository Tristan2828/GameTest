class_name HeartsDisplay
extends Control
## Draws the local player's hearts as simple pixel hearts, with bombs beside them.

const HEART_COLOR: Color = Color(0.9, 0.2, 0.3)
const EMPTY_COLOR: Color = Color(0.25, 0.15, 0.18)
const OUTLINE_COLOR: Color = Color(0.05, 0.03, 0.05)
const HEART_SPACING: float = 12.0

## Each row of the heart shape, as (x offset, width) in pixels; 9 px wide, 8 tall.
const SHAPE: Array[Vector2i] = [
	Vector2i(1, 3), Vector2i(0, 9), Vector2i(0, 9), Vector2i(0, 9),
	Vector2i(1, 7), Vector2i(2, 5), Vector2i(3, 3), Vector2i(4, 1),
]

const BOMB_COLOR: Color = Color(0.75, 0.65, 1.0)
const BOMB_FUSE_COLOR: Color = Color(1.0, 0.8, 0.4)

var bombs: int = 0
var hearts: int = 0
var max_hearts: int = 0


func set_hearts(current: int, maximum: int) -> void:
	if current == hearts and maximum == max_hearts:
		return
	hearts = current
	max_hearts = maximum
	queue_redraw()


func set_bombs(count: int) -> void:
	if count == bombs:
		return
	bombs = count
	queue_redraw()


func _draw() -> void:
	var bombs_x := max_hearts * HEART_SPACING + 6.0
	for i: int in bombs:
		var center := Vector2(bombs_x + i * 10.0 + 4.0, 4.5)
		draw_circle(center, 4.0, OUTLINE_COLOR)
		draw_circle(center, 3.0, BOMB_COLOR)
		draw_rect(Rect2(center + Vector2(1, -5), Vector2(1, 2)), BOMB_FUSE_COLOR)
	for i: int in max_hearts:
		var origin := Vector2(i * HEART_SPACING, 0)
		var color := HEART_COLOR if i < hearts else EMPTY_COLOR
		for row: int in SHAPE.size():
			var span: Vector2i = SHAPE[row]
			draw_rect(Rect2(origin + Vector2(span.x - 1, row), Vector2(span.y + 2, 1)), OUTLINE_COLOR)
		for row: int in SHAPE.size():
			var span: Vector2i = SHAPE[row]
			draw_rect(Rect2(origin + Vector2(span.x, row), Vector2(span.y, 1)), color)
