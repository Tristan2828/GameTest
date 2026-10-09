class_name GameCursor
extends RefCounted
## The mouse cursor during play: a high-contrast crosshair (or ring / dot) in the
## player's chosen style, size and color, so it's easy to find in a crowd of
## bullets. Menus keep the normal arrow. Settings stores the choices; the arena
## says when we're in play.
##
## The image is built in code as pixel art (one color plus a dark outline), then
## scaled up to match the window's pixel size. It's a hardware cursor
## (Input.set_custom_mouse_cursor), so it never lags behind the mouse.

const STYLES: Array[String] = ["System arrow", "Crosshair", "Ring", "Dot"]
const SIZES: Array[String] = ["Small", "Medium", "Large", "Huge"]
## Cursor pixels per game pixel, relative to the window's scale.
const SIZE_FACTORS: Array[float] = [0.67, 1.0, 1.5, 2.0]
const COLOR_NAMES: Array[String] = ["White", "Yellow", "Cyan", "Green", "Pink", "Red", "Orange"]
const COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.0, 0.92, 0.3), Color(0.35, 0.95, 1.0), Color(0.45, 1.0, 0.4),
	Color(1.0, 0.45, 0.9), Color(1.0, 0.3, 0.3), Color(1.0, 0.6, 0.2),
]
const OUTLINE: Color = Color(0.05, 0.02, 0.08)
## Windows refuses cursors bigger than this.
const MAX_PIXELS: int = 128
## Base size (game pixels) of the drawn shapes, before the outline.
const BASE_SIZE: int = 13

## True while a stage is being played (set by the arena).
static var _in_game: bool = false


static func set_in_game(on: bool) -> void:
	if on == _in_game:
		return
	_in_game = on
	refresh()


## Applies the current Settings (call after they change).
static func refresh() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not _in_game or Settings.cursor_style <= 0:
		Input.set_custom_mouse_cursor(null)
		return
	var image := build_image(Settings.cursor_style, Settings.cursor_color, pixel_scale(Settings.cursor_size))
	var texture := ImageTexture.create_from_image(image)
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, Vector2(image.get_size()) / 2.0)


## Screen pixels per cursor pixel: the window's integer scale times the size choice.
static func pixel_scale(size_index: int) -> int:
	var window_scale := 1.0
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		window_scale = maxf(floorf(tree.root.size.y / 360.0), 1.0)
	var factor := SIZE_FACTORS[clampi(size_index, 0, SIZE_FACTORS.size() - 1)]
	return maxi(roundi(window_scale * factor), 1)


## The cursor picture: `style` (STYLES index, 1+), `color_index` (COLORS), scaled
## up by `scale` with nearest-neighbor so it stays crisp. Odd size, centered.
static func build_image(style: int, color_index: int, scale: int = 1) -> Image:
	var size := BASE_SIZE + 2  # Room for the outline.
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var color := COLORS[clampi(color_index, 0, COLORS.size() - 1)]
	var c := size / 2
	match style:
		1:  # Crosshair: four arms with a gap, and a center dot.
			for d: int in range(3, 7):
				for p: Vector2i in [Vector2i(c + d, c), Vector2i(c - d, c), Vector2i(c, c + d), Vector2i(c, c - d)]:
					image.set_pixelv(p, color)
			image.set_pixel(c, c, color)
		2:  # Ring with a center dot.
			for y: int in size:
				for x: int in size:
					var distance := Vector2(x - c, y - c).length()
					if absf(distance - 4.5) < 0.6:
						image.set_pixel(x, y, color)
			image.set_pixel(c, c, color)
		_:  # Dot: a small solid disc.
			for y: int in size:
				for x: int in size:
					if Vector2(x - c, y - c).length() <= 2.3:
						image.set_pixel(x, y, color)
	_add_outline(image)
	var final_size := mini(size * maxi(scale, 1), MAX_PIXELS)
	image.resize(final_size, final_size, Image.INTERPOLATE_NEAREST)
	return image


## Every empty pixel touching a colored one becomes dark: readable on any floor.
static func _add_outline(image: Image) -> void:
	var size := image.get_size()
	var source := image.duplicate() as Image
	for y: int in size.y:
		for x: int in size.x:
			if source.get_pixel(x, y).a > 0.0:
				continue
			for oy: int in range(-1, 2):
				for ox: int in range(-1, 2):
					var nx := x + ox
					var ny := y + oy
					if nx >= 0 and ny >= 0 and nx < size.x and ny < size.y and source.get_pixel(nx, ny).a > 0.0:
						image.set_pixel(x, y, OUTLINE)
