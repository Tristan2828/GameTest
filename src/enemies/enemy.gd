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
	if type.is_boss:
		_draw_boss_crown()
	draw_circle(Vector2.ZERO, type.radius, body)
	draw_circle(Vector2(-type.radius * 0.35, -type.radius * 0.2), maxf(type.radius * 0.18, 1.0), EYE_COLOR)
	draw_circle(Vector2(type.radius * 0.35, -type.radius * 0.2), maxf(type.radius * 0.18, 1.0), EYE_COLOR)
	if type.is_boss:
		draw_rect(Rect2(-type.radius * 0.4, type.radius * 0.25, type.radius * 0.8, 3.0), BOSS_MOUTH_COLOR)
	if type.show_hp_bar and hp_ratio < 1.0:
		var bar := Rect2(-type.radius, -type.radius - 5.0, type.radius * 2.0, 2.0)
		draw_rect(bar, HP_BACK_COLOR)
		bar.size.x *= hp_ratio
		draw_rect(bar, HP_FILL_COLOR)


func _draw_boss_crown() -> void:
	var r := type.radius
	for side: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(side * r * 0.45, -r * 0.7), Vector2(side * r * 1.15, -r * 1.45), Vector2(side * r * 0.85, -r * 0.35)]),
			BOSS_HORN_COLOR)
