extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")


func _player(character: int) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup(1, 0, Vector2(300, 300), Rect2(0, 0, 1600, 1000), character)
	add_child_autofree(player)
	return player


func test_four_distinct_characters() -> void:
	assert_eq(Characters.ALL.size(), 4)
	var names: Dictionary[String, bool] = {}
	for stats: CharacterStats in Characters.ALL:
		names[stats.display_name] = true
		assert_false(stats.perk_name.is_empty(), stats.display_name)
		assert_false(stats.perk_description.is_empty(), stats.display_name)
	assert_eq(names.size(), 4)


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
	assert_gt(keeper.max_hp, wanderer.max_hp)
	assert_lt(keeper.move_speed, wanderer.move_speed)
	assert_lt(witch.max_hp, wanderer.max_hp)
	assert_gt(witch.move_speed, wanderer.move_speed)


func test_perks_are_in_the_numbers() -> void:
	assert_gt(Characters.get_character(Characters.Id.GRAVEKEEPER).recovery, 0.0, "Mortimer regenerates")
	assert_gt(Characters.get_character(Characters.Id.HEXBLADE_WITCH).crit_chance, 0.0, "Morwen crits")
	assert_gt(Characters.get_character(Characters.Id.NECROMANCER).kill_burst_damage, 0, "Vesper's kills burst")


func test_every_hero_has_their_own_main_weapon() -> void:
	assert_eq(Characters.get_character(Characters.Id.WANDERER).main_weapon, CharacterStats.MainWeapon.BOLTS)
	assert_eq(Characters.get_character(Characters.Id.GRAVEKEEPER).main_weapon, CharacterStats.MainWeapon.SCYTHE)
	assert_eq(Characters.get_character(Characters.Id.HEXBLADE_WITCH).main_weapon, CharacterStats.MainWeapon.LIGHTNING)
	assert_eq(Characters.get_character(Characters.Id.NECROMANCER).main_weapon, CharacterStats.MainWeapon.SPEARS)
	for stats: CharacterStats in Characters.ALL:
		assert_true(PixelArt.has_sprite(stats.main_weapon_icon), stats.display_name)
		assert_false(stats.main_weapon_name.is_empty(), stats.display_name)


func test_hits_are_plain_now_no_second_wind() -> void:
	var player := _player(Characters.Id.WANDERER)
	player.take_bullet(player.health.max_hp)
	assert_true(player.is_downed())


func test_spawn_data_carries_the_character_to_every_peer() -> void:
	RunSetup.characters[42] = Characters.Id.HEXBLADE_WITCH
	assert_eq(RunSetup.character_for(42), Characters.Id.HEXBLADE_WITCH)
	assert_eq(RunSetup.character_for(7), Characters.Id.WANDERER, "unchosen = Wanderer")
	RunSetup.characters.clear()

