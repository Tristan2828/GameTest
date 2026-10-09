class_name CharacterPortrait
extends Control
## A character's sprite drawn big (for the lobby cards), in the player's color.

@export var character_id: int = 0
@export var color: Color = Color(0.36, 0.78, 0.95)
@export var scale_factor: float = 2.0


func _draw() -> void:
	PixelArt.draw(self, Characters.get_character(character_id).sprite, size / 2.0, color, false, false, scale_factor)
