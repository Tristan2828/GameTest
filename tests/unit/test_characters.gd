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
		assert_false(stats.ability_name.is_empty(), stats.display_name)
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
	assert_gt(keeper.max_hearts, wanderer.max_hearts)
	assert_lt(keeper.move_speed, wanderer.move_speed)
	assert_lt(witch.max_hearts, wanderer.max_hearts)
	assert_gt(witch.move_speed, wanderer.move_speed)
	assert_eq(wanderer.ability, CharacterStats.Ability.DASH)
	assert_eq(keeper.ability, CharacterStats.Ability.GRAVE_BLAST)
	assert_eq(witch.ability, CharacterStats.Ability.HEX_SNARE)
	assert_eq(Characters.get_character(Characters.Id.NECROMANCER).ability, CharacterStats.Ability.BONE_EFFIGY)


func test_every_hero_has_their_own_main_weapon() -> void:
	assert_eq(Characters.get_character(Characters.Id.WANDERER).main_weapon, CharacterStats.MainWeapon.BOLTS)
	assert_eq(Characters.get_character(Characters.Id.GRAVEKEEPER).main_weapon, CharacterStats.MainWeapon.SCYTHE)
	assert_eq(Characters.get_character(Characters.Id.HEXBLADE_WITCH).main_weapon, CharacterStats.MainWeapon.LIGHTNING)
	assert_eq(Characters.get_character(Characters.Id.NECROMANCER).main_weapon, CharacterStats.MainWeapon.SPEARS)
	for stats: CharacterStats in Characters.ALL:
		assert_true(PixelArt.has_sprite(stats.main_weapon_icon), stats.display_name)
		assert_false(stats.main_weapon_name.is_empty(), stats.display_name)


func test_every_character_has_a_different_ability() -> void:
	var abilities: Dictionary[int, bool] = {}
	for stats: CharacterStats in Characters.ALL:
		abilities[stats.ability] = true
		assert_gt(stats.ability_cooldown, 0.0, stats.display_name)
	assert_eq(abilities.size(), Characters.ALL.size())


func test_hits_are_plain_now_no_second_wind() -> void:
	var player := _player(Characters.Id.WANDERER)
	player.take_hit(5)
	assert_true(player.is_downed())


func test_grave_blast_clears_bullets_damages_and_heals() -> void:
	Net.start_solo()
	RunSetup.characters[1] = Characters.Id.GRAVEKEEPER
	var arena: Arena = preload("res://src/arena/arena.tscn").instantiate()
	add_child_autofree(arena)
	await wait_process_frames(2)
	var keeper := arena._player_by_id(1)
	assert_eq(keeper.stats.ability_name, "Grave Blast")
	var at := keeper.state.position
	arena._enemy_bullets.spawn(at + Vector2(100, 0), Vector2.ZERO, 1, 5.0, 0)
	arena._enemy_bullets.spawn(at + Vector2(400, 0), Vector2.ZERO, 1, 5.0, 0)
	var ghoul := arena._enemies.spawn(EnemyTypes.Id.GHOUL, at + Vector2(50, 0))
	arena._enemies.rebuild_grid()
	keeper.health.take_hit(2, 0.0)
	arena._on_player_ability_used(keeper)
	assert_eq(arena._enemy_bullets.count(), 1, "the far bullet survives")
	assert_eq(ghoul.hp, ghoul.max_hp - keeper.stats.blast_damage)
	assert_eq(keeper.health.hearts, keeper.health.max_hearts - 1)
	assert_true(keeper.health.is_invulnerable())
	RunSetup.characters.clear()


func test_spawn_data_carries_the_character_to_every_peer() -> void:
	RunSetup.characters[42] = Characters.Id.HEXBLADE_WITCH
	assert_eq(RunSetup.character_for(42), Characters.Id.HEXBLADE_WITCH)
	assert_eq(RunSetup.character_for(7), Characters.Id.WANDERER, "unchosen = Wanderer")
	RunSetup.characters.clear()


func test_ability_marker_only_for_slow_abilities() -> void:
	assert_false(Player.shows_ability_marker(Characters.get_character(Characters.Id.WANDERER).ability_cooldown),
		"Dash is too quick: the marker would flicker")
	for id: int in [Characters.Id.GRAVEKEEPER, Characters.Id.NECROMANCER, Characters.Id.HEXBLADE_WITCH]:
		assert_true(Player.shows_ability_marker(Characters.get_character(id).ability_cooldown), str(id))
