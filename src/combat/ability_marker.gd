class_name AbilityMarker
extends Node2D
## Purely visual: a lingering ability on the ground, spawned on every peer from
## the host's event. HEX = the Witch's Hex Snare sigil; EFFIGY = the
## Necromancer's Bone Effigy (sprite plus its lure ring).

enum Kind { HEX, EFFIGY }

const HEX_COLOR: Color = Color(0.72, 0.42, 1.0)
const POP_IN_SECONDS: float = 0.15
const FADE_SECONDS: float = 0.4
const RUNES: int = 8

var kind: Kind = Kind.HEX
## HEX: the sigil's radius. EFFIGY: the lure radius.
var radius: float = 50.0
var duration: float = 3.0
## Player color (P pixels of the effigy).
var color: Color = Color.WHITE

var _time: float = 0.0
## Kinds already captured with --screenshot-dir (one picture each).
static var _screenshots_taken: Array[Kind] = []


func _ready() -> void:
	if not LaunchOptions.screenshot_dir.is_empty() and not _screenshots_taken.has(kind):
		_screenshots_taken.append(kind)
		await get_tree().create_timer(0.6).timeout
		if is_inside_tree():
			Main.save_screenshot(get_tree(), "ability_%s.png" % Kind.keys()[kind].to_lower())


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var grow := minf(_time / POP_IN_SECONDS, 1.0)
	var fade := clampf((duration - _time) / FADE_SECONDS, 0.0, 1.0)
	match kind:
		Kind.HEX:
			_draw_hex(grow, fade)
		Kind.EFFIGY:
			_draw_effigy(grow, fade)


func _draw_hex(grow: float, fade: float) -> void:
	var r := radius * (1.0 - pow(1.0 - grow, 3.0))
	draw_circle(Vector2.ZERO, r, Color(HEX_COLOR, 0.13 * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(HEX_COLOR, 0.8 * fade), 1.0)
	draw_arc(Vector2.ZERO, r * 0.72, 0.0, TAU, 40, Color(HEX_COLOR, 0.35 * fade), 1.0)
	# Runes orbit slowly between the two rings.
	var spin := _time * 0.9
	for i: int in RUNES:
		var at := Vector2.from_angle(spin + TAU * i / RUNES) * r * 0.86
		draw_rect(Rect2(at.round() - Vector2(1, 1), Vector2(3, 3)), Color(HEX_COLOR.lightened(0.3), 0.9 * fade))
	# A five-point star across the middle.
	var points := PackedVector2Array()
	for i: int in 6:
		points.append(Vector2.from_angle(-PI / 2.0 - spin * 0.5 + TAU * 2.0 * i / 5.0) * r * 0.66)
	draw_polyline(points, Color(HEX_COLOR, 0.5 * fade), 1.0)


func _draw_effigy(grow: float, fade: float) -> void:
	# Lure ring pulses so it reads as "come here".
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(color, (0.15 + 0.15 * pulse) * fade), 1.0)
	# Shakes harder as it's about to burst.
	var left := duration - _time
	var shake := Vector2.ZERO
	if left < 1.0:
		shake = Vector2(randf_range(-1.0, 1.0), 0.0).round() * (1.0 - left) * 2.0
	var rise := (1.0 - grow) * 6.0
	PixelArt.draw(self, "bone_effigy", Vector2(0, -4 + rise) + shake, color, false, false, 1.0, Color(1, 1, 1, grow))
