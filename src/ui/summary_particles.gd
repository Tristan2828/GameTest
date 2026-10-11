class_name SummaryParticles
extends Control
## Victory: gold and white confetti drifting down. Defeat: dim embers rising.
## One cheap draw call per speck (about 60 of them).

const COUNT: int = 60

var _victory: bool
var _specks: Array[Vector4] = []  # x, y, speed, phase
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(victory: bool) -> void:
	_victory = victory
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()


func _ready() -> void:
	var area := get_viewport_rect().size
	for i: int in COUNT:
		_specks.append(Vector4(_rng.randf() * area.x, _rng.randf() * area.y, _rng.randf_range(14.0, 34.0), _rng.randf() * TAU))


func _process(delta: float) -> void:
	var area := get_viewport_rect().size
	for i: int in _specks.size():
		var speck := _specks[i]
		speck.y += speck.z * delta * (1.0 if _victory else -0.7)
		speck.w += delta * 2.0
		if speck.y > area.y + 4.0:
			speck.y = -4.0
			speck.x = _rng.randf() * area.x
		elif speck.y < -4.0:
			speck.y = area.y + 4.0
			speck.x = _rng.randf() * area.x
		_specks[i] = speck
	queue_redraw()


func _draw() -> void:
	for i: int in _specks.size():
		var speck := _specks[i]
		var at := Vector2(speck.x + sin(speck.w) * 6.0, speck.y).round()
		if _victory:
			var colors: Array[Color] = [Color(0.95, 0.85, 0.55), Color(1, 1, 1), Color(0.95, 0.6, 0.35), Color(0.6, 0.8, 1.0)]
			var flip := absf(sin(speck.w * 1.3)) > 0.5
			draw_rect(Rect2(at, Vector2(2, 1) if flip else Vector2(1, 2)), Color(colors[i % colors.size()], 0.8))
		else:
			var glow := 0.35 + 0.35 * sin(speck.w * 1.7)
			draw_rect(Rect2(at, Vector2(1, 1)), Color(0.95, 0.4 + 0.2 * glow, 0.25, glow))
