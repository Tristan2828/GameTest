class_name CharacterPortrait
extends Control
## A small drawing of a character (body + hat/hood), for the lobby cards.
## Mirrors Player._draw_look at a bigger scale.

@export var character_id: int = 0
@export var color: Color = Color(0.36, 0.78, 0.95)
@export var scale_factor: float = 2.0


func _draw() -> void:
	var stats := Characters.get_character(character_id)
	var r := stats.body_radius * scale_factor
	var center := size / 2.0 + Vector2(0, r * 0.4)
	var dark := color.darkened(0.45)
	draw_circle(center, r, color)
	match stats.look:
		CharacterStats.Look.HOOD:
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-r, -r * 0.1), center + Vector2(-r * 0.6, -r * 1.0), center + Vector2(0, -r * 1.35),
				center + Vector2(r * 0.6, -r * 1.0), center + Vector2(r, -r * 0.1), center + Vector2(r * 0.55, -r * 0.55),
				center + Vector2(-r * 0.55, -r * 0.55)]), dark)
		CharacterStats.Look.WIDE_HAT:
			draw_rect(Rect2(center + Vector2(-r * 1.4, -r * 0.75), Vector2(r * 2.8, 2.0 * scale_factor)), dark)
			draw_rect(Rect2(center + Vector2(-r * 0.7, -r * 1.45), Vector2(r * 1.4, r * 0.75)), dark)
		CharacterStats.Look.WITCH_HAT:
			draw_rect(Rect2(center + Vector2(-r * 1.3, -r * 0.7), Vector2(r * 2.6, 1.5 * scale_factor)), dark)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-r * 0.7, -r * 0.65), center + Vector2(r * 0.7, -r * 0.65), center + Vector2(r * 0.9, -r * 2.2)]), dark)
	draw_circle(center, stats.hitbox_radius * scale_factor * 0.6, Color.WHITE)
