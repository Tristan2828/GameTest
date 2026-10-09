class_name LevelPips
extends Control
## A row of small squares showing an upgrade's (or weapon's) level: filled for
## levels you have, a blinking gold one for the level you'd gain, hollow for the
## rest up to the maximum. With no maximum, only filled + new pips are drawn.

const PIP: float = 5.0
const GAP: float = 2.0
## More pips than this (only possible without a maximum) are drawn as a "+".
const MAX_DRAWN: int = 10
const OWNED_COLOR: Color = Color(0.55, 0.85, 1.0)
const NEW_COLOR: Color = Color(0.95, 0.78, 0.4)
const EMPTY_COLOR: Color = Color(0.36, 0.3, 0.46)

## Levels already owned.
var owned: int = 0:
	set(value):
		owned = value
		_resize()
## Highest level (0 = no limit).
var maximum: int = 0:
	set(value):
		maximum = value
		_resize()
## Show the next level as a blinking gold pip.
var show_next: bool = true:
	set(value):
		show_next = value
		_resize()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()


func _process(_delta: float) -> void:
	if show_next and is_visible_in_tree():
		queue_redraw()


## How many pips there are in total (owned, next and empty).
func total_pips() -> int:
	return maxi(maximum, owned + (1 if show_next else 0))


## How many pips to draw (capped at MAX_DRAWN; the rest become a "+").
func pip_count() -> int:
	return mini(total_pips(), MAX_DRAWN)


func _width() -> float:
	var slots := pip_count() + (1 if total_pips() > MAX_DRAWN else 0)
	return maxf(slots * (PIP + GAP) - GAP, 0.0)


func _resize() -> void:
	custom_minimum_size = Vector2(_width(), PIP)
	queue_redraw()


func _draw() -> void:
	var count := pip_count()
	var left := floorf((size.x - _width()) / 2.0)
	var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 130.0)
	for i: int in count:
		var rect := Rect2(left + i * (PIP + GAP), 0.0, PIP, PIP)
		if i < owned:
			draw_rect(rect, OWNED_COLOR)
		elif i == owned and show_next:
			draw_rect(rect, Color(NEW_COLOR, blink))
			_outline(rect, NEW_COLOR)
		else:
			_outline(rect, EMPTY_COLOR)
	if total_pips() > count:
		var x := left + count * (PIP + GAP)
		draw_rect(Rect2(x, 2.0, 5.0, 1.0), OWNED_COLOR)
		draw_rect(Rect2(x + 2.0, 0.0, 1.0, 5.0), OWNED_COLOR)


## A 1px hollow square (draw_rect's own outline lands between pixels).
func _outline(rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), color)
	draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - 1.0), Vector2(rect.size.x, 1.0)), color)
	draw_rect(Rect2(rect.position, Vector2(1.0, rect.size.y)), color)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 1.0, 0.0), Vector2(1.0, rect.size.y)), color)
