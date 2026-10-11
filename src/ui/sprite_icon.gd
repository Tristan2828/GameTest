class_name SpriteIcon
extends Control
## Draws one PixelArt sprite centered in this control, at the largest whole-number
## scale (up to `max_scale`) that fits. Used by the compendium rows.

@export var sprite: String = ""
@export var tint: Color = Color(0.36, 0.78, 0.95)
@export var max_scale: int = 2
## A square slot drawn behind the icon (dark, with a border in this color);
## transparent = no slot. `frame_size` is the slot's size (centered).
@export var frame: Color = Color(0, 0, 0, 0)
@export var frame_size: Vector2 = Vector2(36, 36)

const FRAME_BACK: Color = Color(0.05, 0.035, 0.08, 1.0)


func _init(sprite_name: String = "", min_size: Vector2 = Vector2(36, 36)) -> void:
	sprite = sprite_name
	custom_minimum_size = min_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Whole-number scale so the sprite fits `area` (at least 1, at most `largest`).
static func fit_scale(sprite_size: Vector2i, area: Vector2, largest: int) -> int:
	var fits := floori(minf(area.x / maxf(sprite_size.x, 1.0), area.y / maxf(sprite_size.y, 1.0)))
	return clampi(fits, 1, largest)


func _draw() -> void:
	if frame.a > 0.0:
		var slot := Rect2(((size - frame_size) / 2.0).round(), frame_size)
		draw_rect(slot, FRAME_BACK)
		draw_rect(slot.grow(-1.0), Color(frame, 0.12))
		draw_rect(slot, Color(frame, 0.9), false, 1.0)
		# Small corner notches, like a gem setting.
		for corner: Vector2 in [slot.position, Vector2(slot.end.x - 2.0, slot.position.y),
				Vector2(slot.position.x, slot.end.y - 2.0), slot.end - Vector2(2.0, 2.0)]:
			draw_rect(Rect2(corner, Vector2(2, 2)), frame.lightened(0.4))
	if not PixelArt.has_sprite(sprite):
		return
	var scale := fit_scale(PixelArt.size_of(sprite), size, max_scale)
	PixelArt.draw(self, sprite, (size / 2.0).round(), tint, false, false, scale)
