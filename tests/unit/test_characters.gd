extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")


func _player(character: int) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup(1, 0, Vector2(300, 300), Rect2(0, 0, 1600, 1000), character)
	add_child_autofree(player)
	return player


func test_three_distinct_characters() -> void:
	assert_eq(Characters.ALL.size(), 3)
	var names: Dictionary[String, bool] = {}
	for stats: CharacterStats in Characters.ALL:
		names[stats.display_name] = true
		assert_false(stats.ability_name.is_empty(), stats.display_name)
	assert_eq(names.size(), 3)


func test_players_get_their_own_copy_of_character_stats() -> void:
	var a := _player(Characters.Id.GRAVEKEEPER)
	var b := _player(Characters.Id.GRAVEKEEPER)
	a.apply_upgrade(0)
	assert_ne(a.stats.bullet_damage, b.stats.bullet_damage)
	assert_eq(Characters.get_character(Characters.Id.GRAVEKEEPER).bullet_damage, b.stats.bullet_damage)


func test_character_trade_offs() -> void:
	var wanderer := Characters.get_character(Characters.Id.WANDERER)
	var keeper := Characters.get_character(Characters.Id.GRAVEKEEPER)
	var witch := Characters.get_character(Characters.Id.HEXBLADE_WITCH)
	assert_gt(keeper.max_hearts, wanderer.max_hearts)
	assert_lt(keeper.move_speed, wanderer.move_speed)
	assert_lt(witch.max_hearts, wanderer.max_hearts)
	assert_gt(witch.move_speed, wanderer.move_speed)
	assert_lt(witch.dash_cooldown, wanderer.dash_cooldown)


func test_gravekeeper_shotgun_fires_a_wide_fan_and_extra_bolt_adds_pellets() -> void:
	var keeper := Characters.get_character(Characters.Id.GRAVEKEEPER)
	var pattern := keeper.shot_pattern as ShotPatterns.Id
	var pellets := ShotPatterns.angles(pattern, 0.0, 7, 1)
	assert_eq(pellets.size(), 5)
	assert_gt(pellets[4] - pellets[0], deg_to_rad(20.0), "wide spread")
	assert_eq(ShotPatterns.angles(pattern, 0.0, 7, 2).size(), 7)


func test_second_wind_saves_the_wanderer_once_per_stage() -> void:
	var player := _player(Characters.Id.WANDERER)
	player.health.hearts = 1
	assert_true(player.take_hit(1))
	assert_eq(player.health.hearts, 1, "saved")
	assert_true(player.health.is_invulnerable())
	player.health.invulnerable_left = 0.0
	player.take_hit(1)
	assert_true(player.is_downed(), "only once")
	player.respawn(Vector2(100, 100))
	player.health.hearts = 1
	player.take_hit(1)
	assert_false(player.is_downed(), "recharges each stage")


func test_other_characters_have_no_second_wind() -> void:
	var player := _player(Characters.Id.HEXBLADE_WITCH)
	player.take_hit(5)
	assert_true(player.is_downed())


func test_gravekeeper_bombs_heal() -> void:
	Net.start_solo()
	RunSetup.characters[1] = Characters.Id.GRAVEKEEPER
	var arena: Arena = preload("res://src/arena/arena.tscn").instantiate()
	add_child_autofree(arena)
	await wait_process_frames(2)
	var keeper := arena._player_by_id(1)
	assert_eq(keeper.stats.display_name, "Gravekeeper")
	assert_eq(keeper.bombs_left, 3)
	keeper.health.take_hit(2, 0.0)
	arena._on_player_bomb_requested(keeper)
	assert_eq(keeper.health.hearts, keeper.health.max_hearts - 1)
	RunSetup.characters.clear()


func test_spawn_data_carries_the_character_to_every_peer() -> void:
	RunSetup.characters[42] = Characters.Id.HEXBLADE_WITCH
	assert_eq(RunSetup.character_for(42), Characters.Id.HEXBLADE_WITCH)
	assert_eq(RunSetup.character_for(7), Characters.Id.WANDERER, "unchosen = Wanderer")
	RunSetup.characters.clear()
