extends GutTest
## The in-game cursor image (GameCursor).


## Images store 8-bit colors, so compare loosely.
func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01 and absf(a.a - b.a) < 0.01


func test_every_style_draws_a_centered_outlined_shape() -> void:
	for style: int in range(1, GameCursor.STYLES.size()):
		var image := GameCursor.build_image(style, 0, 1)
		var size := image.get_size()
		assert_eq(size.x, size.y)
		assert_eq(size.x % 2, 1, "odd size, so the hotspot is a real center pixel")
		var c := size.x / 2
		assert_true(_same(image.get_pixel(c, c), GameCursor.COLORS[0]), "style %d has a center dot" % style)
		var has_outline := false
		for y: int in size.y:
			for x: int in size.x:
				has_outline = has_outline or _same(image.get_pixel(x, y), GameCursor.OUTLINE)
		assert_true(has_outline, "style %d has a dark outline" % style)


func test_color_and_scale_choices() -> void:
	var small := GameCursor.build_image(1, 3, 1)
	var big := GameCursor.build_image(1, 3, 3)
	assert_eq(big.get_width(), small.get_width() * 3)
	var c := big.get_width() / 2
	assert_true(_same(big.get_pixel(c, c), GameCursor.COLORS[3]))


func test_cursor_never_exceeds_the_os_limit() -> void:
	assert_lte(GameCursor.build_image(2, 0, 50).get_width(), GameCursor.MAX_PIXELS)


func test_option_lists_line_up() -> void:
	assert_eq(GameCursor.COLORS.size(), GameCursor.COLOR_NAMES.size())
	assert_eq(GameCursor.SIZES.size(), GameCursor.SIZE_FACTORS.size())
