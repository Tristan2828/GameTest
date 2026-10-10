class_name HealthBar
extends Control
## The local player's HP as a red bar with "73 / 100" on it (top-left of the HUD).

const FILL_COLOR: Color = Color(0.85, 0.2, 0.28)
## The part just lost fades out in a lighter red, so you see how much a hit took.
const LOST_COLOR: Color = Color(1.0, 0.65, 0.6)
const BACK_COLOR: Color = Color(0.2, 0.1, 0.14, 0.9)
const EDGE_COLOR: Color = Color(0.05, 0.03, 0.05)
const TEXT_COLOR: Color = Color(1.0, 0.95, 0.95)
## How fast the "just lost" part catches up (share of the bar per second).
const LOST_CATCH_UP: float = 0.6

var hp: int = 0
var max_hp: int = 0
var _shown_ratio: float = 0.0


func set_health(current: int, maximum: int) -> void:
	if current == hp and maximum == max_hp:
		return
	hp = current
	max_hp = maximum
	if ratio() > _shown_ratio:
		_shown_ratio = ratio()
	queue_redraw()


func ratio() -> float:
	return clampf(float(hp) / maxf(max_hp, 1.0), 0.0, 1.0)


func _process(delta: float) -> void:
	if _shown_ratio > ratio():
		_shown_ratio = maxf(_shown_ratio - LOST_CATCH_UP * delta, ratio())
		queue_redraw()


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area.grow(1.0), EDGE_COLOR)
	draw_rect(area, BACK_COLOR)
	draw_rect(Rect2(Vector2.ZERO, Vector2(floorf(size.x * _shown_ratio), size.y)), LOST_COLOR)
	draw_rect(Rect2(Vector2.ZERO, Vector2(floorf(size.x * ratio()), size.y)), FILL_COLOR)
	var font := ThemeDB.fallback_font
	var text := "%d / %d" % [hp, max_hp]
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var at := Vector2(roundf((size.x - width) / 2.0), size.y - 1.0)
	draw_string(font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, EDGE_COLOR)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, TEXT_COLOR)
