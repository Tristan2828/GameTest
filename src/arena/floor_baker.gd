class_name FloorBaker
extends RefCounted
## Paints a stage's whole floor into one image, once per stage: pixel-art
## ground, walls, props with shadows, and warm candle light. The arena then
## draws that single texture every frame, which costs almost nothing.
##
## Everything comes from a seeded random generator, so every peer bakes the
## identical floor without any network traffic.

const TILE: int = 16
## Wall thickness around the play area, in pixels.
const WALL: int = 6
## Keep props out of the middle, where everyone spawns.
const CLEAR_RADIUS: float = 90.0
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.35)
## Props are dimmed and partly see-through, so they read as floor detail and
## never compete with monsters, bullets and pickups for attention (they're also
## drawn about half a monster's size, without the black outline creatures have).
const PROP_BRIGHTNESS: float = 0.8
const PROP_OPACITY: float = 0.55
const CANDLE_GLOW: Color = Color(1.0, 0.62, 0.25)
const CARPET_COLOR: Color = Color(0.33, 0.07, 0.09)
const CARPET_EDGE_COLOR: Color = Color(0.72, 0.52, 0.2)
const WATER_COLOR: Color = Color(0.07, 0.12, 0.12)
const WATER_SHINE_COLOR: Color = Color(0.22, 0.34, 0.33)
## Width of the Cathedral's carpet aisles.
const AISLE: int = 48


## The floor for `stage`, covering `size` plus the wall border on every side.
static func bake(stage: StageDef, size: Vector2i, seed_value: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var image := Image.create(size.x + WALL * 2, size.y + WALL * 2, false, Image.FORMAT_RGBA8)
	var area := Rect2i(Vector2i(WALL, WALL), size)
	image.fill_rect(area, stage.grout_color)
	match stage.prop_style:
		StageDef.PropStyle.MARSH:
			_marsh_ground(image, area, stage, rng)
		StageDef.PropStyle.CATHEDRAL:
			_cathedral_ground(image, area, stage, rng)
		_:
			_crypt_ground(image, area, stage, rng)
	_props(image, area, stage, rng)
	_walls(image, area, stage)
	return image


# --- Ground ------------------------------------------------------------------

## Stone slabs of mixed sizes (1x1, 2x1, 1x2 tiles) with bevels, cracks and moss.
static func _crypt_ground(image: Image, area: Rect2i, stage: StageDef, rng: RandomNumberGenerator) -> void:
	var columns := area.size.x / TILE
	var rows := area.size.y / TILE
	var taken := PackedByteArray()
	taken.resize(columns * rows)
	for row: int in rows:
		for column: int in columns:
			if taken[row * columns + column] != 0:
				continue
			var span := Vector2i(1, 1)
			var roll := rng.randf()
			if roll < 0.35 and column + 1 < columns and taken[row * columns + column + 1] == 0:
				span = Vector2i(2, 1)
			elif roll < 0.5 and row + 1 < rows:
				span = Vector2i(1, 2)
			for dy: int in span.y:
				for dx: int in span.x:
					taken[(row + dy) * columns + column + dx] = 1
			var rect := Rect2i(area.position + Vector2i(column, row) * TILE, span * TILE)
			var base := _pick(stage.stone_colors, rng)
			_slab(image, rect, base, stage, rng, 0.15, 0.1)


## Blotchy mud from pixelated noise, murky puddles, and the odd cobblestone.
static func _marsh_ground(image: Image, area: Rect2i, stage: StageDef, rng: RandomNumberGenerator) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.012
	var block := 4
	# Five mud shades: the stage's mid color scaled darker/brighter (keeps its hue).
	var shades: Array[Color] = []
	var base: Color = stage.stone_colors[1]
	for i: int in 5:
		var k := 0.8 + 0.14 * i
		shades.append(Color(base.r * k, base.g * k, base.b * k))
	for y: int in range(0, area.size.y, block):
		for x: int in range(0, area.size.x, block):
			var value := noise.get_noise_2d(x, y) * 0.5 + 0.5 + rng.randf_range(-0.03, 0.03)
			var index := clampi(int(value * shades.size()), 0, shades.size() - 1)
			image.fill_rect(Rect2i(area.position + Vector2i(x, y), Vector2i(block, block)), shades[index])
	for i: int in 45:
		var center := _random_point(area, rng, 0.0)
		_puddle(image, center, Vector2i(rng.randi_range(10, 26), rng.randi_range(5, 10)))
	for i: int in 160:
		var at := _random_point(area, rng, 0.0)
		var rect := Rect2i(at, Vector2i(rng.randi_range(5, 8), rng.randi_range(4, 6)))
		_slab(image, rect, stage.stone_colors[stage.stone_colors.size() - 1].lightened(0.15), stage, rng, 0.0, 0.0)
	for i: int in 260:
		var at := _random_point(area, rng, 0.0)
		image.fill_rect(Rect2i(at, Vector2i(rng.randi_range(1, 3), 1)), stage.moss_color)


## Checkered marble with glowing ember cracks, and a red carpet cross.
static func _cathedral_ground(image: Image, area: Rect2i, stage: StageDef, rng: RandomNumberGenerator) -> void:
	var big := TILE * 2
	for row: int in area.size.y / big + 1:
		for column: int in area.size.x / big + 1:
			var rect := Rect2i(area.position + Vector2i(column, row) * big, Vector2i(big, big)).intersection(area)
			if rect.size.x <= 2 or rect.size.y <= 2:
				continue
			var light := (row + column) % 2 == 0
			var base: Color = stage.stone_colors[3 if light else 0]
			_slab(image, rect, base, stage, rng, 0.2, 0.0, true)
	var middle := area.get_center()
	_carpet(image, Rect2i(Vector2i(middle.x - AISLE / 2, area.position.y), Vector2i(AISLE, area.size.y)))
	_carpet(image, Rect2i(Vector2i(area.position.x, middle.y - AISLE / 2), Vector2i(area.size.x, AISLE)))


## One beveled stone slab with speckles, maybe a crack and some moss.
## `glowing_cracks` paints the stage's accent color along cracks (embers).
static func _slab(image: Image, rect: Rect2i, base: Color, stage: StageDef, rng: RandomNumberGenerator,
		crack_chance: float, moss_chance: float, glowing_cracks: bool = false) -> void:
	var inner := Rect2i(rect.position, rect.size - Vector2i(1, 1))
	if inner.size.x <= 0 or inner.size.y <= 0:
		return
	image.fill_rect(inner, base)
	var light := base.lightened(0.09)
	var dark := base.darkened(0.25)
	image.fill_rect(Rect2i(inner.position, Vector2i(inner.size.x, 1)), light)
	image.fill_rect(Rect2i(inner.position, Vector2i(1, inner.size.y)), light)
	image.fill_rect(Rect2i(inner.position + Vector2i(0, inner.size.y - 1), Vector2i(inner.size.x, 1)), dark)
	image.fill_rect(Rect2i(inner.position + Vector2i(inner.size.x - 1, 0), Vector2i(1, inner.size.y)), dark)
	for i: int in inner.get_area() / 14:
		var at := inner.position + Vector2i(rng.randi_range(1, inner.size.x - 2), rng.randi_range(1, inner.size.y - 2))
		image.set_pixelv(at, base.lightened(0.05) if rng.randf() < 0.5 else base.darkened(0.1))
	if rng.randf() < crack_chance:
		var at := inner.position + Vector2i(rng.randi_range(2, inner.size.x - 3), rng.randi_range(2, inner.size.y - 3))
		for step: int in rng.randi_range(5, 12):
			if not inner.grow(-1).has_point(at):
				break
			image.set_pixelv(at, stage.moss_color if glowing_cracks and step % 3 == 0 else stage.crack_color)
			at += Vector2i(rng.randi_range(-1, 1), rng.randi_range(0, 1))
	if rng.randf() < moss_chance:
		for i: int in rng.randi_range(3, 8):
			var at := Vector2i(rect.position.x + rng.randi_range(0, rect.size.x - 1), rect.end.y - 1 - rng.randi_range(0, 1))
			image.set_pixelv(at, stage.moss_color)


static func _puddle(image: Image, center: Vector2i, radius: Vector2i) -> void:
	for dy: int in range(-radius.y, radius.y + 1):
		var half := int(radius.x * sqrt(maxf(1.0 - float(dy * dy) / float(radius.y * radius.y), 0.0)))
		var span := Rect2i(Vector2i(center.x - half, center.y + dy), Vector2i(half * 2, 1))
		image.fill_rect(span.intersection(Rect2i(Vector2i.ZERO, image.get_size())), WATER_COLOR)
	image.fill_rect(Rect2i(center + Vector2i(-radius.x / 2, -radius.y / 2), Vector2i(maxi(radius.x / 2, 2), 1)), WATER_SHINE_COLOR)


static func _carpet(image: Image, rect: Rect2i) -> void:
	image.fill_rect(rect, CARPET_COLOR)
	var vertical := rect.size.y > rect.size.x
	var edge := Vector2i(2, rect.size.y) if vertical else Vector2i(rect.size.x, 2)
	var far := Vector2i(rect.size.x - 4, 0) if vertical else Vector2i(0, rect.size.y - 4)
	image.fill_rect(Rect2i(rect.position + (Vector2i(2, 0) if vertical else Vector2i(0, 2)), edge), CARPET_EDGE_COLOR)
	image.fill_rect(Rect2i(rect.position + far, edge), CARPET_EDGE_COLOR)
	# A simple repeating diamond pattern down the middle.
	var length := rect.size.y if vertical else rect.size.x
	var middle := rect.get_center()
	for along: int in range(8, length, 16):
		var at := Vector2i(middle.x, rect.position.y + along) if vertical else Vector2i(rect.position.x + along, middle.y)
		for d: int in 3:
			for side: Vector2i in [Vector2i(d, 2 - d), Vector2i(-d, 2 - d), Vector2i(d, d - 2), Vector2i(-d, d - 2)]:
				image.set_pixelv(at + side, CARPET_EDGE_COLOR.darkened(0.2))


# --- Props -------------------------------------------------------------------

static func _props(image: Image, area: Rect2i, stage: StageDef, rng: RandomNumberGenerator) -> void:
	var placements: Array[Array] = []
	match stage.prop_style:
		StageDef.PropStyle.MARSH:
			placements = [["reeds", 70], ["stump", 14], ["bones", 22], ["skull_pile", 6], ["grave_cross", 8]]
		StageDef.PropStyle.CATHEDRAL:
			placements = [["pew", 22], ["pillar_stump", 14], ["candelabra", 16], ["rubble", 30], ["skull_pile", 6]]
		_:
			placements = [["grave", 36], ["grave_cross", 16], ["bones", 30], ["skull_pile", 12], ["candle", 22]]
	for placement: Array in placements:
		var sprite: String = placement[0]
		for i: int in placement[1]:
			var at := _random_point(area.grow(-20), rng, CLEAR_RADIUS)
			if stage.prop_style == StageDef.PropStyle.CATHEDRAL and _on_aisle(at, area):
				continue
			var lit := sprite == "candle" or sprite == "candelabra"
			_stamp(image, sprite, at, 1.0 if lit else PROP_BRIGHTNESS, 1.0 if lit else PROP_OPACITY)
			if lit:
				_glow(image, at, 18 if sprite == "candelabra" else 12)


## Draws a sprite with a soft shadow under it; `at` is its bottom-middle.
## `opacity` below 1 lets the floor show through.
static func _stamp(image: Image, sprite: String, at: Vector2i, brightness: float = 1.0, opacity: float = 1.0) -> void:
	var sprite_image := PixelArt.texture(sprite).get_image()
	if brightness < 1.0 or opacity < 1.0:
		sprite_image = sprite_image.duplicate()
		for y: int in sprite_image.get_height():
			for x: int in sprite_image.get_width():
				var pixel := sprite_image.get_pixel(x, y)
				if pixel.a > 0.0:
					sprite_image.set_pixel(x, y, Color(pixel.r * brightness, pixel.g * brightness, pixel.b * brightness, pixel.a * opacity))
	var size := sprite_image.get_size()
	var shadow := Color(SHADOW_COLOR, SHADOW_COLOR.a * opacity)
	for dx: int in range(-size.x / 2, size.x / 2 + 1):
		var shadow_at := at + Vector2i(dx, 0)
		if Rect2i(Vector2i.ZERO, image.get_size()).has_point(shadow_at):
			image.set_pixelv(shadow_at, image.get_pixelv(shadow_at).blend(shadow))
	image.blend_rect(sprite_image, Rect2i(Vector2i.ZERO, size), at - Vector2i(size.x / 2, size.y))


## Warm light around a flame (brightens the floor, strongest in the middle).
static func _glow(image: Image, at: Vector2i, radius: int) -> void:
	var center := at - Vector2i(0, 6)
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var distance := sqrt(float(dx * dx + dy * dy)) / radius
			if distance >= 1.0:
				continue
			var point := center + Vector2i(dx, dy)
			if not Rect2i(Vector2i.ZERO, image.get_size()).has_point(point):
				continue
			var strength := (1.0 - distance) * 0.18
			image.set_pixelv(point, image.get_pixelv(point).lerp(CANDLE_GLOW, strength))


# --- Walls -------------------------------------------------------------------

static func _walls(image: Image, area: Rect2i, stage: StageDef) -> void:
	var full := Rect2i(Vector2i.ZERO, image.get_size())
	var mortar := stage.wall_color.darkened(0.35)
	for y: int in full.size.y:
		for x: int in full.size.x:
			if area.has_point(Vector2i(x, y)):
				continue
			# Little bricks: a mortar line every 3 rows, joints offset per row.
			var is_mortar := y % 3 == 2 or (x + (y / 3) * 4) % 8 == 0
			image.set_pixel(x, y, mortar if is_mortar else stage.wall_color)
	var edge := area.grow(1)
	image.fill_rect(Rect2i(edge.position, Vector2i(edge.size.x, 1)), stage.wall_edge_color)
	image.fill_rect(Rect2i(edge.position, Vector2i(1, edge.size.y)), stage.wall_edge_color)
	image.fill_rect(Rect2i(Vector2i(edge.position.x, edge.end.y - 1), Vector2i(edge.size.x, 1)), stage.wall_edge_color)
	image.fill_rect(Rect2i(Vector2i(edge.end.x - 1, edge.position.y), Vector2i(1, edge.size.y)), stage.wall_edge_color)


# --- Helpers -----------------------------------------------------------------

static func _pick(colors: Array[Color], rng: RandomNumberGenerator) -> Color:
	return colors[rng.randi() % colors.size()]


static func _random_point(area: Rect2i, rng: RandomNumberGenerator, keep_clear: float) -> Vector2i:
	for attempt: int in 10:
		var point := Vector2i(rng.randi_range(area.position.x, area.end.x - 1), rng.randi_range(area.position.y, area.end.y - 1))
		if Vector2(point).distance_to(Vector2(area.get_center())) > keep_clear:
			return point
	return area.position


static func _on_aisle(point: Vector2i, area: Rect2i) -> bool:
	var middle := area.get_center()
	return absi(point.x - middle.x) < AISLE / 2 + 12 or absi(point.y - middle.y) < AISLE / 2 + 12
