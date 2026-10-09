class_name ArenaFloor
extends Node2D
## The arena's ground: dark stone tiles with seeded variation, cracks, moss, and
## decorative graves, bones and candles. Purely visual (no collision).
##
## Drawn once and cached by Godot until queue_redraw(), so it costs nothing per
## frame. A fixed seed means every player sees the same arena.

const TILE: int = 16
const GRAVE_COLOR: Color = Color(0.2, 0.19, 0.23)
const GRAVE_SHADE_COLOR: Color = Color(0.15, 0.14, 0.17)
const BONE_COLOR: Color = Color(0.32, 0.3, 0.27)
const CANDLE_COLOR: Color = Color(0.45, 0.4, 0.33)
const FLAME_COLOR: Color = Color(1.0, 0.7, 0.3)
const GLOW_COLOR: Color = Color(1.0, 0.6, 0.25, 0.06)
const PUDDLE_COLOR: Color = Color(0.05, 0.09, 0.08)
const PUDDLE_SHINE_COLOR: Color = Color(0.2, 0.3, 0.28)
const REED_COLOR: Color = Color(0.25, 0.3, 0.15)
const PEW_COLOR: Color = Color(0.2, 0.11, 0.07)
const PEW_TOP_COLOR: Color = Color(0.28, 0.16, 0.1)
const PILLAR_COLOR: Color = Color(0.3, 0.24, 0.22)
const PILLAR_SHADE_COLOR: Color = Color(0.18, 0.13, 0.12)
const EMBER_COLOR: Color = Color(1.0, 0.55, 0.2)
const EMBER_GLOW_COLOR: Color = Color(1.0, 0.35, 0.1, 0.07)

@export var bounds: Rect2 = Rect2(0, 0, 1600, 1000)
@export var seed_value: int = 1337
@export var grave_count: int = 45
@export var bone_count: int = 70
@export var candle_count: int = 18
## Keep decorations out of the middle so the spawn area stays clean.
@export var clear_radius: float = 90.0

var _stage: StageDef = null


## Repaint the floor for a stage (each stage has its own palette and props).
func apply_stage(stage: StageDef) -> void:
	_stage = stage
	queue_redraw()


func _draw() -> void:
	if _stage == null:
		_stage = Stages.get_stage(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_draw_tiles(rng)
	match _stage.prop_style:
		StageDef.PropStyle.MARSH:
			for i: int in grave_count:
				_draw_puddle(_prop_spot(rng), rng)
			for i: int in bone_count:
				_draw_reeds(_prop_spot(rng), rng)
			for i: int in bone_count / 2:
				_draw_bones(_prop_spot(rng), rng)
		StageDef.PropStyle.CATHEDRAL:
			for i: int in grave_count / 2:
				_draw_pew(_prop_spot(rng), rng)
			for i: int in grave_count / 3:
				_draw_pillar_stump(_prop_spot(rng))
			for i: int in bone_count:
				_draw_ember(_prop_spot(rng))
			for i: int in candle_count:
				_draw_candle(_prop_spot(rng))
		_:
			for i: int in bone_count:
				_draw_bones(_prop_spot(rng), rng)
			for i: int in grave_count:
				_draw_grave(_prop_spot(rng), rng)
			for i: int in candle_count:
				_draw_candle(_prop_spot(rng))
	_draw_walls()


func _draw_tiles(rng: RandomNumberGenerator) -> void:
	draw_rect(bounds, _stage.grout_color)
	for x: int in range(int(bounds.position.x), int(bounds.end.x), TILE):
		for y: int in range(int(bounds.position.y), int(bounds.end.y), TILE):
			var color: Color = _stage.stone_colors[rng.randi() % _stage.stone_colors.size()]
			draw_rect(Rect2(x + 1, y + 1, TILE - 1, TILE - 1), color)
			var roll := rng.randf()
			if roll < 0.06:
				# A crack: two short connected lines.
				var a := Vector2(x + rng.randi_range(3, 12), y + rng.randi_range(3, 12))
				var b := a + Vector2(rng.randi_range(-4, 4), rng.randi_range(2, 5))
				var c := b + Vector2(rng.randi_range(-4, 4), rng.randi_range(-2, 3))
				draw_line(a, b, _stage.crack_color)
				draw_line(b, c, _stage.crack_color)
			elif roll < 0.09:
				draw_rect(Rect2(x + rng.randi_range(1, 9), y + rng.randi_range(1, 9), rng.randi_range(3, 6), rng.randi_range(2, 4)), _stage.moss_color)


func _prop_spot(rng: RandomNumberGenerator) -> Vector2:
	var inner := bounds.grow(-24.0)
	for attempt: int in 10:
		var spot := Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y)).round()
		if spot.distance_to(bounds.get_center()) > clear_radius:
			return spot
	return inner.position


func _draw_grave(at: Vector2, rng: RandomNumberGenerator) -> void:
	var width := rng.randi_range(7, 10)
	var height := rng.randi_range(9, 13)
	var top := at - Vector2(width / 2.0, height)
	draw_rect(Rect2(top + Vector2(1, 2), Vector2(width, height)), GRAVE_SHADE_COLOR)
	draw_rect(Rect2(top + Vector2(0, 2), Vector2(width, height - 2)), GRAVE_COLOR)
	draw_circle(top + Vector2(width / 2.0, 3), width / 2.0, GRAVE_COLOR)
	if rng.randf() < 0.5:
		draw_rect(Rect2(top + Vector2(width / 2.0 - 0.5, 3), Vector2(1, 5)), GRAVE_SHADE_COLOR)
		draw_rect(Rect2(top + Vector2(width / 2.0 - 2, 4), Vector2(4, 1)), GRAVE_SHADE_COLOR)


func _draw_bones(at: Vector2, rng: RandomNumberGenerator) -> void:
	for i: int in rng.randi_range(1, 3):
		var direction := Vector2.from_angle(rng.randf() * TAU)
		var start := at + Vector2(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
		draw_line(start, start + direction * rng.randi_range(4, 7), BONE_COLOR)
	if rng.randf() < 0.25:
		draw_circle(at + Vector2(3, -2), 2.0, BONE_COLOR)


func _draw_candle(at: Vector2) -> void:
	draw_circle(at, 14.0, GLOW_COLOR)
	draw_rect(Rect2(at + Vector2(-1, -4), Vector2(2, 4)), CANDLE_COLOR)
	draw_rect(Rect2(at + Vector2(-0.5, -6), Vector2(1, 2)), FLAME_COLOR)


func _draw_puddle(at: Vector2, rng: RandomNumberGenerator) -> void:
	var size := Vector2(rng.randi_range(10, 22), rng.randi_range(5, 10))
	draw_rect(Rect2(at - size / 2.0, size), PUDDLE_COLOR)
	draw_rect(Rect2(at - size / 2.0 + Vector2(2, 1), Vector2(size.x * 0.4, 1)), PUDDLE_SHINE_COLOR)


func _draw_reeds(at: Vector2, rng: RandomNumberGenerator) -> void:
	for i: int in rng.randi_range(2, 4):
		var base := at + Vector2(i * 2 - 3, 0)
		draw_line(base, base + Vector2(rng.randi_range(-2, 2), -rng.randi_range(5, 9)), REED_COLOR)


func _draw_pew(at: Vector2, rng: RandomNumberGenerator) -> void:
	var width := rng.randi_range(18, 30)
	draw_rect(Rect2(at + Vector2(-width / 2.0, -3), Vector2(width, 5)), PEW_COLOR)
	draw_rect(Rect2(at + Vector2(-width / 2.0, -5), Vector2(width, 2)), PEW_TOP_COLOR)


func _draw_pillar_stump(at: Vector2) -> void:
	draw_circle(at + Vector2(1, 1), 7.0, PILLAR_SHADE_COLOR)
	draw_circle(at, 7.0, PILLAR_COLOR)
	draw_circle(at, 4.0, PILLAR_SHADE_COLOR)


func _draw_ember(at: Vector2) -> void:
	draw_circle(at, 6.0, EMBER_GLOW_COLOR)
	draw_rect(Rect2(at, Vector2(1, 1)), EMBER_COLOR)


func _draw_walls() -> void:
	var thickness := 6.0
	var outer := bounds.grow(thickness)
	draw_rect(Rect2(outer.position, Vector2(outer.size.x, thickness)), _stage.wall_color)
	draw_rect(Rect2(Vector2(outer.position.x, bounds.end.y), Vector2(outer.size.x, thickness)), _stage.wall_color)
	draw_rect(Rect2(outer.position, Vector2(thickness, outer.size.y)), _stage.wall_color)
	draw_rect(Rect2(Vector2(bounds.end.x, outer.position.y), Vector2(thickness, outer.size.y)), _stage.wall_color)
	draw_rect(bounds, _stage.wall_edge_color, false, 1.0)
