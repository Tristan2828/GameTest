class_name CharacterPortrait
extends Control
## A character's sprite drawn big (for the lobby cards), in the player's color.
## Optionally shows a column of color markers for the players who picked it, and
## can walk on the spot (`animate`, the lobby's party cards).

const MARKER_SIZE: float = 4.0
const MARKER_GAP: float = 2.0

## Setters redraw: the lobby changes these after the portrait is first drawn.
@export var character_id: int = 0:
	set(value):
		character_id = value
		queue_redraw()
@export var color: Color = Color(0.36, 0.78, 0.95):
	set(value):
		if value != color:
			color = value
			queue_redraw()
@export var scale_factor: float = 2.0:
	set(value):
		scale_factor = value
		queue_redraw()
## Walk on the spot with a little bob (redraws every frame while on).
var animate: bool = false:
	set(value):
		animate = value
		set_process(value)
## Where in the walk cycle this portrait starts, so a row of them doesn't march in step.
var walk_offset: float = 0.0
## Slot colors of the players who chose this character (drawn under the sprite).
var pickers: Array[Color] = []:
	set(value):
		if value != pickers:
			pickers = value
			queue_redraw()


func _ready() -> void:
	set_process(animate)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var sprite := Characters.get_character(character_id).sprite
	var center := size / 2.0
	if animate:
		var steps := Time.get_ticks_msec() / 1000.0 * Player.WALK_STEPS_PER_SECOND * 0.5 + walk_offset
		sprite = PixelArt.walk_frame(sprite, true, steps)
		center.y -= roundf(absf(sin(steps * PI))) * scale_factor
		# A soft shadow under the feet.
		var feet := size.y / 2.0 + PixelArt.size_of(sprite).y * scale_factor / 2.0
		draw_rect(Rect2(Vector2(size.x / 2.0 - 5.0 * scale_factor, feet - scale_factor), Vector2(10.0 * scale_factor, 2.0 * scale_factor)),
			Color(0, 0, 0, 0.35))
	PixelArt.draw(self, sprite, center, color, false, false, scale_factor)
	if pickers.is_empty():
		return
	# A column left of the sprite (the card has room there; below is the name).
	for i: int in pickers.size():
		var rect := Rect2(-MARKER_SIZE - 8.0, 4.0 + i * (MARKER_SIZE + MARKER_GAP), MARKER_SIZE, MARKER_SIZE)
		draw_rect(rect.grow(1.0), Color(0.05, 0.03, 0.08))
		draw_rect(rect, pickers[i])
