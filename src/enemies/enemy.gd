class_name Enemy
extends Node2D
## One pooled enemy. EnemyManager creates a fixed number of these once and reuses
## them by calling activate()/deactivate().
## The host owns HP and position; clients only display synced values.

const FLASH_DURATION: float = 0.08
const CLIENT_SMOOTHING: float = 12.0
const HP_BACK_COLOR: Color = Color(0.15, 0.05, 0.08)
const HP_FILL_COLOR: Color = Color(0.85, 0.2, 0.28)
## Milliseconds per animation frame (bat wings, imp flicker).
const ANIMATION_MS: float = 140.0
## Steps per second of the walk cycle, and how long the attack pose shows.
const WALK_STEPS_PER_SECOND: float = 5.0
const ATTACK_POSE_SECONDS: float = 0.35

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
var facing_left: bool = false
var _last_position: Vector2 = Vector2.ZERO
var _moving: bool = false
var _walk_phase: float = 0.0
var _attack_left: float = 0.0
## The sprite drawn last frame (redraw only when it changes).
var _shown_sprite: String = ""


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
	_attack_left = 0.0
	_last_position = at
	queue_redraw()


## Show the attack pose briefly (called on every peer when this enemy fires).
func play_attack() -> void:
	_attack_left = ATTACK_POSE_SECONDS


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
	# Face and animate the way we're walking.
	var moved := position - _last_position
	_last_position = position
	_moving = moved.length() > 0.05
	if _moving:
		_walk_phase += delta * WALK_STEPS_PER_SECOND
		if absf(moved.x) > 0.05:
			facing_left = moved.x < 0.0
	_attack_left = maxf(_attack_left - delta, 0.0)
	if _flash_left > 0.0:
		_flash_left -= delta
		queue_redraw()
	elif _current_sprite() != _shown_sprite or type.sprite_frames > 1:
		queue_redraw()


## Which frame to show right now: attack pose, flap/flicker frames, or walk cycle.
func _current_sprite() -> String:
	if type.sprite.is_empty():
		return ""
	if _attack_left > 0.0 and PixelArt.has_sprite(type.sprite + "_attack"):
		return type.sprite + "_attack"
	if type.sprite_frames > 1:
		var frame := (int(Time.get_ticks_msec() / ANIMATION_MS) + pool_index) % type.sprite_frames
		return type.sprite if frame == 0 else "%s_%d" % [type.sprite, frame]
	return PixelArt.walk_frame(type.sprite, _moving, _walk_phase + pool_index * 0.5)


func _draw() -> void:
	if not type.sprite.is_empty():
		_shown_sprite = _current_sprite()
		PixelArt.draw(self, _shown_sprite, Vector2.ZERO, Color.WHITE, _flash_left > 0.0, facing_left, type.sprite_scale)
	else:
		draw_circle(Vector2.ZERO, type.radius, Color.WHITE if _flash_left > 0.0 else type.color)
	if type.show_hp_bar and hp_ratio < 1.0:
		var bar := Rect2(-type.radius, -type.radius - 5.0, type.radius * 2.0, 2.0)
		draw_rect(bar, HP_BACK_COLOR)
		bar.size.x *= hp_ratio
		draw_rect(bar, HP_FILL_COLOR)
