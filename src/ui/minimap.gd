class_name Minimap
extends Control
## A small map of the whole arena in the HUD corner: the walls, what your screen
## currently shows, every player, the horde, the boss and weapon altars. The
## side you're close to lights up red so you know you're backing into a wall.

const BACK_COLOR: Color = Color(0.03, 0.02, 0.05, 0.75)
const BORDER_COLOR: Color = Color(0.42, 0.33, 0.55)
const VIEW_COLOR: Color = Color(0.9, 0.88, 1.0, 0.35)
const ENEMY_COLOR: Color = Color(0.75, 0.25, 0.3, 0.55)
const BOSS_COLOR: Color = Color(1.0, 0.25, 0.3)
const ALTAR_COLOR: Color = Color(1.0, 0.8, 0.35)
const EDGE_WARNING_COLOR: Color = Color(1.0, 0.3, 0.3)
## How close to a wall (in arena pixels) before that side lights up.
const EDGE_WARNING_DISTANCE: float = 70.0

var arena_size: Vector2 = Vector2(1600, 1000)
var view: Rect2 = Rect2()
## Each player: [position, color, is_local]
var players: Array[Array] = []
var enemies: PackedVector2Array = PackedVector2Array()
var altars: PackedVector2Array = PackedVector2Array()
var boss: Vector2 = Vector2.INF
var local_position: Vector2 = Vector2.INF


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
		draw_rect(Rect2((at * scale_factor).floor() - Vector2.ONE, Vector2(3, 3)), ALTAR_COLOR)
	if boss.is_finite():
		draw_rect(Rect2((boss * scale_factor).floor() - Vector2(2, 2), Vector2(5, 5)), BOSS_COLOR)
	if view.size != Vector2.ZERO:
		draw_rect(Rect2((view.position * scale_factor).floor(), (view.size * scale_factor).floor()), VIEW_COLOR, false, 1.0)
	for marker: Array in players:
		var at: Vector2 = marker[0]
		var dot := 3.0 if marker[2] else 2.0
		draw_rect(Rect2((at * scale_factor).floor() - Vector2(1, 1), Vector2(dot, dot)), marker[1])
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 1.0)
	_draw_edge_warnings()


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
