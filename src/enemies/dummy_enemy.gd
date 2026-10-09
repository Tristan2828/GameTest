class_name DummyEnemy
extends Node2D
## Training dummy: has HP, flashes when hit, never attacks. Pooled by EnemyManager.
## The host owns its HP and position; clients only display synced values.

const FLASH_DURATION: float = 0.08
const CLIENT_SMOOTHING: float = 15.0
const BODY_COLOR: Color = Color(0.45, 0.25, 0.55)
const HP_BACK_COLOR: Color = Color(0.15, 0.05, 0.08)
const HP_FILL_COLOR: Color = Color(0.85, 0.2, 0.28)

var pool_index: int = -1
var radius: float = 9.0
var max_hp: int = 100
var hp: int = 100
var active: bool = false
var home: Vector2 = Vector2.ZERO
var wander_phase: float = 0.0
## Clients: latest position from the host, approached smoothly.
var target_position: Vector2 = Vector2.ZERO

var _flash_left: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	visible = active


func activate(at: Vector2, hit_points: int) -> void:
	active = true
	visible = true
	max_hp = hit_points
	hp = hit_points
	home = at
	position = at
	target_position = at
	_flash_left = 0.0
	queue_redraw()


func deactivate() -> void:
	active = false
	visible = false


## Returns true if this hit killed the dummy.
func apply_damage(amount: int) -> bool:
	if not active or hp <= 0:
		return false
	hp = maxi(hp - amount, 0)
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
	draw_circle(Vector2.ZERO, radius, Color.WHITE if _flash_left > 0.0 else BODY_COLOR)
	var bar := Rect2(-radius, -radius - 5.0, radius * 2.0, 2.0)
	draw_rect(bar, HP_BACK_COLOR)
	bar.size.x *= float(hp) / float(max_hp)
	draw_rect(bar, HP_FILL_COLOR)
