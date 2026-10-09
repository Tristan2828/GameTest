class_name Enemy
extends Node2D
## One pooled enemy. EnemyManager creates a fixed number of these once and reuses
## them by calling activate()/deactivate().
## The host owns HP and position; clients only display synced values.

const FLASH_DURATION: float = 0.08
const CLIENT_SMOOTHING: float = 12.0
const HP_BACK_COLOR: Color = Color(0.15, 0.05, 0.08)
const HP_FILL_COLOR: Color = Color(0.85, 0.2, 0.28)
const EYE_COLOR: Color = Color(1.0, 0.85, 0.4)
const BOSS_HORN_COLOR: Color = Color(0.35, 0.3, 0.28)
const BOSS_MOUTH_COLOR: Color = Color(0.2, 0.08, 0.1)
const HAT_COLOR: Color = Color(0.12, 0.1, 0.14)
const MITRE_COLOR: Color = Color(0.55, 0.12, 0.12)
const MITRE_TRIM_COLOR: Color = Color(0.95, 0.75, 0.35)
const HELMET_COLOR: Color = Color(0.32, 0.35, 0.42)
const HELMET_SLIT_COLOR: Color = Color(0.95, 0.4, 0.2)

var pool_index: int = -1
var type_id: int = 0
var type: EnemyType = EnemyTypes.get_type(0)
var active: bool = false
var hp: int = 1
var max_hp: int = 1
## Clients only know HP as a fraction (0..1), for HP bars.
var hp_ratio: float = 1.0
var wobble_phase: float = 0.0
## Host: seconds until this enemy may fire again (ranged enemies).
var fire_cooldown: float = 0.0
## Host: set when hit, cleared after each snapshot so clients can flash too.
var hit_since_snapshot: bool = false
## Clients: latest position from the host, approached smoothly.
var target_position: Vector2 = Vector2.ZERO

var _flash_left: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	visible = active


## `hit_points` > 0 overrides the type's max HP (bosses scale with players).
func activate(enemy_type_id: int, at: Vector2, hit_points: int = 0) -> void:
	type_id = enemy_type_id
	type = EnemyTypes.get_type(enemy_type_id)
	active = true
	visible = true
	max_hp = hit_points if hit_points > 0 else type.max_hp
	hp = max_hp
	hp_ratio = 1.0
	position = at
	target_position = at
	wobble_phase = randf() * TAU
	# Stagger first volleys so a group doesn't fire in perfect sync.
	fire_cooldown = type.fire_interval * randf_range(0.5, 1.0)
	hit_since_snapshot = false
	_flash_left = 0.0
	queue_redraw()


func deactivate() -> void:
	active = false
	visible = false


## Host only. Returns true if this hit killed the enemy.
func apply_damage(amount: int) -> bool:
	if not active or hp <= 0:
		return false
	hp = maxi(hp - amount, 0)
	hp_ratio = float(hp) / float(max_hp)
	hit_since_snapshot = true
	flash()
	return hp == 0


func flash() -> void:
	_flash_left = FLASH_DURATION
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return
	if not multiplayer.is_server():
		position = position.lerp(target_position, 1.0 - exp(-CLIENT_SMOOTHING * delta))
	if _flash_left > 0.0:
		_flash_left -= delta
		queue_redraw()


func _draw() -> void:
	var body := Color.WHITE if _flash_left > 0.0 else type.color
	if type.look == EnemyType.Look.HORNS or type.look == EnemyType.Look.WINGS:
		_draw_horns_or_wings()
	draw_circle(Vector2.ZERO, type.radius, body)
	_draw_headwear()
	draw_circle(Vector2(-type.radius * 0.35, -type.radius * 0.2), maxf(type.radius * 0.18, 1.0), EYE_COLOR)
	draw_circle(Vector2(type.radius * 0.35, -type.radius * 0.2), maxf(type.radius * 0.18, 1.0), EYE_COLOR)
	if type.is_boss:
		draw_rect(Rect2(-type.radius * 0.4, type.radius * 0.25, type.radius * 0.8, 3.0), BOSS_MOUTH_COLOR)
	if type.show_hp_bar and hp_ratio < 1.0:
		var bar := Rect2(-type.radius, -type.radius - 5.0, type.radius * 2.0, 2.0)
		draw_rect(bar, HP_BACK_COLOR)
		bar.size.x *= hp_ratio
		draw_rect(bar, HP_FILL_COLOR)


## Drawn behind the body.
func _draw_horns_or_wings() -> void:
	var r := type.radius
	for side: float in [-1.0, 1.0]:
		if type.look == EnemyType.Look.HORNS:
			draw_colored_polygon(PackedVector2Array([
				Vector2(side * r * 0.45, -r * 0.7), Vector2(side * r * 1.15, -r * 1.45), Vector2(side * r * 0.85, -r * 0.35)]),
				BOSS_HORN_COLOR)
		else:
			draw_colored_polygon(PackedVector2Array([
				Vector2(side * r * 0.6, -r * 0.3), Vector2(side * r * 2.0, -r * 0.9), Vector2(side * r * 1.6, r * 0.3),
				Vector2(side * r * 0.7, r * 0.3)]), type.color.darkened(0.35))


## Drawn on top of the body.
func _draw_headwear() -> void:
	var r := type.radius
	match type.look:
		EnemyType.Look.WITCH_HAT:
			draw_rect(Rect2(-r * 1.1, -r * 0.85, r * 2.2, r * 0.25), HAT_COLOR)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-r * 0.6, -r * 0.8), Vector2(r * 0.6, -r * 0.8), Vector2(r * 0.2, -r * 2.0)]), HAT_COLOR)
		EnemyType.Look.MITRE:
			draw_colored_polygon(PackedVector2Array([
				Vector2(-r * 0.55, -r * 0.7), Vector2(r * 0.55, -r * 0.7), Vector2(r * 0.4, -r * 1.7),
				Vector2(0, -r * 2.0), Vector2(-r * 0.4, -r * 1.7)]), MITRE_COLOR)
			draw_rect(Rect2(-1, -r * 1.75, 2, r * 0.8), MITRE_TRIM_COLOR)
			draw_rect(Rect2(-r * 0.25, -r * 1.4, r * 0.5, 2), MITRE_TRIM_COLOR)
		EnemyType.Look.HELMET:
			draw_rect(Rect2(-r * 0.9, -r * 0.95, r * 1.8, r * 0.75), HELMET_COLOR)
			draw_rect(Rect2(-r * 0.6, -r * 0.45, r * 1.2, 1.5), HELMET_SLIT_COLOR)
