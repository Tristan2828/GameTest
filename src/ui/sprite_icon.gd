class_name SpriteIcon
extends Control
## Draws one PixelArt sprite centered in this control, at the largest whole-number
## scale (up to `max_scale`) that fits. Used by the compendium rows.

@export var sprite: String = ""
@export var tint: Color = Color(0.36, 0.78, 0.95)
@export var max_scale: int = 2


func _init(sprite_name: String = "", min_size: Vector2 = Vector2(36, 36)) -> void:
	sprite = sprite_name
	custom_minimum_size = min_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Whole-number scale so the sprite fits `area` (at least 1, at most `largest`).
static func fit_scale(sprite_size: Vector2i, area: Vector2, largest: int) -> int:
	var fits := floori(minf(area.x / maxf(sprite_size.x, 1.0), area.y / maxf(sprite_size.y, 1.0)))
	return clampi(fits, 1, largest)


func _draw() -> void:
	if not PixelArt.has_sprite(sprite):
		return
	var scale := fit_scale(PixelArt.size_of(sprite), size, max_scale)
	PixelArt.draw(self, sprite, (size / 2.0).round(), tint, false, false, scale)
