extends GutTest


func test_every_sprite_is_rectangular_and_uses_known_colors() -> void:
	for sprite: String in PixelArt.SPRITES:
		var rows: Array = PixelArt.SPRITES[sprite]
		var width := String(rows[0]).length()
		for row: String in rows:
			assert_eq(row.length(), width, "%s has uneven rows" % sprite)
			for ch: String in row:
				var known := PixelArt.PALETTE.has(ch) or ch == PixelArt.TINT_CHAR or ch == PixelArt.TINT_SHADE_CHAR
				assert_true(known, "%s uses unknown color '%s'" % [sprite, ch])


func test_every_enemy_and_character_has_its_sprites() -> void:
	for type: EnemyType in EnemyTypes.ALL:
		assert_true(PixelArt.has_sprite(type.sprite), type.display_name)
		for frame: int in range(1, type.sprite_frames):
			assert_true(PixelArt.has_sprite("%s_%d" % [type.sprite, frame]), "%s frame %d" % [type.display_name, frame])
	for stats: CharacterStats in Characters.ALL:
		assert_true(PixelArt.has_sprite(stats.sprite), stats.display_name)
	for sprite: String in ["ghost", "skull", "gem", "gem_big", "coin", "coin_big"]:
		assert_true(PixelArt.has_sprite(sprite), sprite)


func test_sprites_roughly_match_hit_sizes() -> void:
	for type: EnemyType in EnemyTypes.ALL:
		var drawn := Vector2(PixelArt.size_of(type.sprite)) * type.sprite_scale
		var diameter := type.radius * 2.0
		assert_between(drawn.x, diameter * 0.8, diameter * 2.5, "%s width vs hitbox" % type.display_name)


func test_tint_recolors_player_pixels_and_flash_whitens() -> void:
	var red := PixelArt.texture("wanderer", Color.RED).get_image()
	var blue := PixelArt.texture("wanderer", Color.BLUE).get_image()
	var differs := false
	for y: int in red.get_height():
		for x: int in red.get_width():
			if red.get_pixel(x, y) != blue.get_pixel(x, y):
				differs = true
	assert_true(differs, "P pixels follow the tint")
	var flash := PixelArt.texture("shambler", Color.WHITE, true).get_image()
	for y: int in flash.get_height():
		for x: int in flash.get_width():
			var pixel := flash.get_pixel(x, y)
			assert_true(pixel.a == 0.0 or pixel == Color.WHITE)


func test_textures_are_cached() -> void:
	assert_same(PixelArt.texture("bat"), PixelArt.texture("bat"))
