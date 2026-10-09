extends GutTest

const SIZE: Vector2i = Vector2i(320, 200)


func test_same_seed_bakes_the_same_floor_for_every_peer() -> void:
	for stage: StageDef in Stages.ALL:
		var a := FloorBaker.bake(stage, SIZE, 42)
		var b := FloorBaker.bake(stage, SIZE, 42)
		assert_eq(a.get_data(), b.get_data(), stage.title)


func test_floor_includes_the_wall_border() -> void:
	var image := FloorBaker.bake(Stages.get_stage(1), SIZE, 1)
	assert_eq(image.get_size(), SIZE + Vector2i(FloorBaker.WALL, FloorBaker.WALL) * 2)


func test_each_stage_looks_different() -> void:
	var crypt := FloorBaker.bake(Stages.get_stage(1), SIZE, 7).get_pixel(40, 40)
	var marsh := FloorBaker.bake(Stages.get_stage(2), SIZE, 7).get_pixel(40, 40)
	var cathedral := FloorBaker.bake(Stages.get_stage(3), SIZE, 7).get_pixel(40, 40)
	assert_ne(crypt, marsh)
	assert_ne(marsh, cathedral)


func test_floor_has_no_holes() -> void:
	var image := FloorBaker.bake(Stages.get_stage(2), SIZE, 3)
	for y: int in range(0, image.get_height(), 7):
		for x: int in range(0, image.get_width(), 7):
			assert_eq(image.get_pixel(x, y).a, 1.0, "transparent pixel at %d,%d" % [x, y])
