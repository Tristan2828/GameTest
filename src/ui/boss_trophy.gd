class_name BossTrophy
extends Control
## One boss of the run: slain (full color, gold plinth and a gentle bob), the
## killer (red, shaking a little) or not reached (a dark silhouette), with its
## stage's time underneath.

enum State { UNREACHED, SLAIN, KILLER }

var _sprite: String
var _state: int
var _phase: float
var _caption: String


func _init(sprite: String, state: int, phase: float, caption: String = "") -> void:
	_sprite = sprite
	_state = state
	_phase = phase
	_caption = caption
	custom_minimum_size = Vector2(36, 40)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0 + _phase
	var sprite_size := Vector2(PixelArt.size_of(_sprite))
	var scale := clampf(floorf(minf(28.0 / sprite_size.x, 24.0 / sprite_size.y)), 1.0, 2.0)
	if sprite_size.x * scale > 32.0 or sprite_size.y * scale > 26.0:
		scale = 1.0
	var center := Vector2(size.x / 2.0, 13.0)
	var plinth := Rect2(Vector2(size.x / 2.0 - 12.0, 27.0), Vector2(24.0, 3.0))
	match _state:
		State.SLAIN:
			draw_rect(plinth, Color(0.95, 0.78, 0.4))
			draw_rect(Rect2(plinth.position + Vector2(2, 3), Vector2(20, 1)), Color(0.6, 0.45, 0.2))
			center.y -= roundf(absf(sin(now * 2.0)))
			PixelArt.draw(self, _sprite, center.round(), Color.WHITE, false, false, scale)
			var shine := 0.5 + 0.5 * sin(now * 3.0)
			PixelArt.draw(self, "star", (center + Vector2(sprite_size.x * scale / 2.0, -sprite_size.y * scale / 2.0)).round(),
				Color.WHITE, false, false, 1.0, Color(1, 1, 1, 0.5 + 0.5 * shine))
		State.KILLER:
			draw_rect(plinth, Color(0.5, 0.15, 0.15))
			center.x += roundf(sin(now * 23.0) * 0.6)
			PixelArt.draw(self, _sprite, center.round(), Color.WHITE, false, false, scale, Color(1.0, 0.45, 0.45))
		_:
			draw_rect(plinth, Color(0.2, 0.16, 0.26))
			PixelArt.draw(self, _sprite, center.round(), Color.WHITE, false, false, scale, Color(0.08, 0.06, 0.12, 0.9))
	if not _caption.is_empty():
		var font := get_theme_default_font()
		var width := font.get_string_size(_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var color := Color(0.95, 0.85, 0.55) if _state == State.SLAIN else Color(0.6, 0.57, 0.68)
		draw_string(font, Vector2(roundf((size.x - width) / 2.0), 39.0), _caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, color)
