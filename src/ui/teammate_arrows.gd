class_name TeammateArrows
extends Control
## Arrows at the screen edge pointing at teammates who are off screen, in their
## player color. Downed teammates' arrows pulse with a "+" (go revive them).
## Map events (champion lairs, rituals, thieves, chests) get an arrow with their icon.
## Fills the whole HUD; the arena pushes
## in the local view and the teammates' positions every frame.

## Distance from the screen edge to the arrow tip.
const EDGE_MARGIN: float = 10.0
## Teammates this close to the edge (inside it) count as visible: no arrow.
const VISIBLE_INSET: float = 4.0
const OUTLINE_COLOR: Color = Color(0.05, 0.03, 0.08, 0.9)
const REVIVE_COLOR: Color = Color(0.55, 0.95, 0.5)

## The local player's view of the world (empty = draw nothing).
var _view: Rect2 = Rect2()
## [world position, color, is_downed] per teammate.
var _teammates: Array[Array] = []
## [world position, color, sprite] per map event.
var _events: Array[Array] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_state(view: Rect2, teammates: Array[Array], events: Array[Array] = []) -> void:
	_view = view
	_teammates = teammates
	_events = events
	queue_redraw()


## Where the arrow goes on screen for a teammate at `world_position`, or
## Vector2.INF when they're on screen. Pure math, so it's testable.
static func edge_point(view: Rect2, world_position: Vector2, margin: float = EDGE_MARGIN) -> Vector2:
	if view.grow(-VISIBLE_INSET).has_point(world_position):
		return Vector2.INF
	var half := view.size / 2.0 - Vector2(margin, margin)
	var offset := world_position - view.get_center()
	var scale := INF
	if absf(offset.x) > 0.001:
		scale = minf(scale, half.x / absf(offset.x))
	if absf(offset.y) > 0.001:
		scale = minf(scale, half.y / absf(offset.y))
	return view.size / 2.0 + offset * minf(scale, 1.0)


func _draw() -> void:
	if _view.size == Vector2.ZERO:
		return
	for event: Array in _events:
		var at: Vector2 = event[0]
		var tip := edge_point(_view, at, EDGE_MARGIN + 2.0)
		if tip == Vector2.INF:
			continue
		var direction := (at - _view.get_center()).normalized()
		var color: Color = event[1]
		color = color.lerp(Color.WHITE, 0.15 + 0.15 * sin(Time.get_ticks_msec() / 220.0))
		_draw_arrow(tip.round(), direction, color, false)
		var icon_at := (tip - direction * 16.0).round()
		draw_circle(icon_at, 8.0, Color(OUTLINE_COLOR, 0.7))
		PixelArt.draw(self, event[2], icon_at)
	for teammate: Array in _teammates:
		var world: Vector2 = teammate[0]
		var tip := edge_point(_view, world)
		if tip == Vector2.INF:
			continue
		var color: Color = teammate[1]
		var direction := (world - _view.get_center()).normalized()
		var downed: bool = teammate[2]
		if downed:
			color = color.lerp(Color.WHITE, 0.4 + 0.4 * sin(Time.get_ticks_msec() / 150.0))
		_draw_arrow(tip.round(), direction, color)
		if downed:
			var dot := (tip - direction * 13.0).round()
			draw_rect(Rect2(dot + Vector2(-1, -3), Vector2(3, 7)), REVIVE_COLOR)
			draw_rect(Rect2(dot + Vector2(-3, -1), Vector2(7, 3)), REVIVE_COLOR)


## A small arrowhead with a dark outline, plus a dot behind it (unless `dot` is false).
func _draw_arrow(tip: Vector2, direction: Vector2, color: Color, dot: bool = true) -> void:
	var side := direction.orthogonal()
	var points := PackedVector2Array([tip, tip - direction * 8.0 + side * 5.0, tip - direction * 8.0 - side * 5.0])
	var outline := PackedVector2Array([tip + direction * 1.5, tip - direction * 9.5 + side * 6.5, tip - direction * 9.5 - side * 6.5])
	draw_colored_polygon(outline, Color(OUTLINE_COLOR, OUTLINE_COLOR.a * color.a))
	draw_colored_polygon(points, color)
	if not dot:
		return
	draw_circle(tip - direction * 13.0, 2.5, Color(OUTLINE_COLOR, OUTLINE_COLOR.a * color.a))
	draw_circle(tip - direction * 13.0, 1.5, color)
