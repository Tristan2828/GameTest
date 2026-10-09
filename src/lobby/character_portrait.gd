class_name CharacterPortrait
extends Control
## A character's sprite drawn big (for the lobby cards), in the player's color.
## Optionally shows a column of color markers for the players who picked it.

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
## Slot colors of the players who chose this character (drawn under the sprite).
var pickers: Array[Color] = []:
	set(value):
		if value != pickers:
			pickers = value
			queue_redraw()


func _draw() -> void:
	PixelArt.draw(self, Characters.get_character(character_id).sprite, size / 2.0, color, false, false, scale_factor)
	if pickers.is_empty():
		return
	# A column left of the sprite (the card has room there; below is the name).
	for i: int in pickers.size():
		var rect := Rect2(-MARKER_SIZE - 8.0, 4.0 + i * (MARKER_SIZE + MARKER_GAP), MARKER_SIZE, MARKER_SIZE)
		draw_rect(rect.grow(1.0), Color(0.05, 0.03, 0.08))
		draw_rect(rect, pickers[i])
