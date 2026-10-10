class_name Minimap
extends Control
## A small map of the whole arena in the HUD corner: the walls, what your screen
## currently shows, every player, the horde, the boss, weapon altars and map events. The
## side you're close to lights up red so you know you're backing into a wall.
## Each kind of marker has its own tiny outlined shape (PixelArt "mm_*" sprites):
## you = big diamond, teammates = small diamonds, a downed teammate = blinking "+",
## boss = skull, altar = sword, champion = crown, ritual = ring, thief = coin,
## chest = chest. Enemies stay single dots.

const BACK_COLOR: Color = Color(0.03, 0.02, 0.05, 0.75)
const BORDER_COLOR: Color = Color(0.42, 0.33, 0.55)
const VIEW_COLOR: Color = Color(0.9, 0.88, 1.0, 0.35)
const ENEMY_COLOR: Color = Color(0.75, 0.25, 0.3, 0.55)
const BOSS_COLOR: Color = Color(1.0, 0.25, 0.3)
const ALTAR_COLOR: Color = Color(1.0, 0.8, 0.35)
const EDGE_WARNING_COLOR: Color = Color(1.0, 0.3, 0.3)
const OUTLINE_COLOR: Color = Color(0.04, 0.02, 0.07)
const REVIVE_COLOR: Color = Color(0.55, 0.95, 0.5)
## Map event Kind -> minimap shape (same order as MapEvents.Kind).
const EVENT_SHAPES: Array[String] = ["mm_champion", "mm_ritual", "mm_coin", "mm_chest"]
## How close to a wall (in arena pixels) before that side lights up.
const EDGE_WARNING_DISTANCE: float = 70.0

var arena_size: Vector2 = Vector2(1600, 1000)
var view: Rect2 = Rect2()
## Each player: [position, color, is_local, is_downed (optional)]
var players: Array[Array] = []
var enemies: PackedVector2Array = PackedVector2Array()
var altars: PackedVector2Array = PackedVector2Array()
var boss: Vector2 = Vector2.INF
var local_position: Vector2 = Vector2.INF
## [position, color, sprite, kind (optional)] per map event (blinking shapes in the event's color).
var events: Array[Array] = []


func show_state(view_rect: Rect2, player_markers: Array[Array], enemy_positions: PackedVector2Array,
		altar_positions: PackedVector2Array, boss_position: Vector2, local: Vector2) -> void:
	view = view_rect
	players = player_markers
	enemies = enemy_positions
	altars = altar_positions
	boss = boss_position
	local_position = local
	queue_redraw()


func _draw() -> void:
	var scale_factor := size / arena_size
	draw_rect(Rect2(Vector2.ZERO, size), BACK_COLOR)
	for at: Vector2 in enemies:
		draw_rect(Rect2((at * scale_factor).floor(), Vector2.ONE), ENEMY_COLOR)
	for at: Vector2 in altars:
		_draw_marker("mm_altar", at * scale_factor, ALTAR_COLOR)
	var blink := int(Time.get_ticks_msec() / 400) % 2 == 0
	for event: Array in events:
		var color: Color = event[1]
		_draw_marker(shape_for_event(event), (event[0] as Vector2) * scale_factor, color if blink else color.lightened(0.5))
	if boss.is_finite():
		_draw_marker("mm_boss", boss * scale_factor, BOSS_COLOR)
	if view.size != Vector2.ZERO:
		draw_rect(Rect2((view.position * scale_factor).floor(), (view.size * scale_factor).floor()), VIEW_COLOR, false, 1.0)
	# Teammates first, so your own marker is always on top.
	for pass_local: bool in [false, true]:
		for marker: Array in players:
			if bool(marker[2]) != pass_local:
				continue
			var downed: bool = marker.size() > 3 and marker[3]
			var shape := "mm_you" if pass_local else ("mm_downed" if downed else "mm_teammate")
			var color: Color = marker[1]
			if downed and not pass_local:
				color = REVIVE_COLOR if blink else color
			_draw_marker(shape, (marker[0] as Vector2) * scale_factor, color)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 1.0)
	_draw_edge_warnings()


## The minimap shape for a map event marker: by its Kind when given, else by its icon.
static func shape_for_event(event: Array) -> String:
	if event.size() > 3 and int(event[3]) >= 0 and int(event[3]) < EVENT_SHAPES.size():
		return EVENT_SHAPES[int(event[3])]
	match String(event[2]):
		"crown":
			return "mm_champion"
		"icon_ritual":
			return "mm_ritual"
		"chest":
			return "mm_chest"
	return "mm_coin"


## A tiny shape with a dark 1 px outline, centered on `at` (minimap pixels).
func _draw_marker(shape: String, at: Vector2, color: Color) -> void:
	var center := at.floor() + Vector2(0.5, 0.5)
	for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		PixelArt.draw(self, shape, center + offset, color, false, false, 1.0, OUTLINE_COLOR)
	PixelArt.draw(self, shape, center, color)


func _draw_edge_warnings() -> void:
	if not local_position.is_finite():
		return
	if local_position.x < EDGE_WARNING_DISTANCE:
		draw_rect(Rect2(0, 0, 2, size.y), EDGE_WARNING_COLOR)
	if local_position.x > arena_size.x - EDGE_WARNING_DISTANCE:
		draw_rect(Rect2(size.x - 2, 0, 2, size.y), EDGE_WARNING_COLOR)
	if local_position.y < EDGE_WARNING_DISTANCE:
		draw_rect(Rect2(0, 0, size.x, 2), EDGE_WARNING_COLOR)
	if local_position.y > arena_size.y - EDGE_WARNING_DISTANCE:
		draw_rect(Rect2(0, size.y - 2, size.x, 2), EDGE_WARNING_COLOR)
