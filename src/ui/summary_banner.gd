class_name SummaryBanner
extends Control
## The big headline: letters drop in one by one with a bounce, then shimmer
## (a gold wave for victory, a slow red flicker for defeat).

const DROP_SECONDS: float = 0.35
const LETTER_DELAY: float = 0.06
const SIZE: int = 27

var _text: String
var _color: Color
var _victory: bool
var _age: float = 0.0


func _init(text: String, color: Color, victory: bool) -> void:
	_text = text
	_color = color
	_victory = victory
	custom_minimum_size = Vector2(0, 30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var total := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
	var x := roundf((size.x - total) / 2.0)
	var baseline := 25.0
	for i: int in _text.length():
		var letter := _text[i]
		var advance := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
		var t := clampf((_age - i * LETTER_DELAY) / DROP_SECONDS, 0.0, 1.0)
		if t > 0.0:
			# Drop from above and settle with a small bounce.
			var offset := -24.0 * pow(1.0 - t, 2.0) + sin(t * PI) * 3.0 * (1.0 - t)
			var color := _color
			if t >= 1.0:
				var wave := sin(_age * 3.0 - i * 0.6)
				color = _color.lerp(Color.WHITE, 0.25 * maxf(wave, 0.0)) if _victory else \
					_color.darkened(0.15 * (0.5 + 0.5 * sin(_age * 1.7 + i)))
			color.a = t
			var at := Vector2(x, baseline + roundf(offset))
			draw_string(font, at + Vector2(2, 2), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, Color(0.02, 0.01, 0.04, t))
			draw_string(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, color)
		x += advance
