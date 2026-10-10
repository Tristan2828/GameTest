extends GutTest
## Difficulty and Custom Game settings (RunConfig), their lobby pages, and their
## effect on a real solo arena.

const ARENA_SCENE: PackedScene = preload("res://src/arena/arena.tscn")


func after_each() -> void:
	RunSetup.config = RunConfig.new()


func _arena_with(config: RunConfig) -> Arena:
	RunSetup.config = config
	Net.start_solo()
	var arena: Arena = ARENA_SCENE.instantiate()
	add_child_autofree(arena)
	await wait_process_frames(2)
	return arena


# --- RunConfig ---

func test_values_are_clamped_and_snapped() -> void:
	var config := RunConfig.new()
	config.set_value("enemy_health", 9.0)
	assert_eq(config.enemy_health, 3.0)
	config.set_value("enemy_count", 1.1)
	assert_eq(config.enemy_count, 1.0, "snapped to 25% steps")
	config.set_value("hp_bonus", -70)
	assert_eq(config.hp_bonus, -40)
	config.set_value("hp_bonus", 23)
	assert_eq(config.hp_bonus, 20, "snapped to 10 HP steps")
	config.set_value("wave_seconds", 95.0)
	assert_eq(config.wave_seconds, 90.0)


func test_presets_and_names() -> void:
	var config := RunConfig.new()
	assert_eq(config.difficulty_name(), "Normal")
	config.apply_preset("Hard")
	assert_eq(config.difficulty_name(), "Hard")
	assert_gt(config.enemy_health, 1.0)
	config.set_value("coin_rate", 3.0)
	assert_eq(config.difficulty_name(), "Custom")
	for preset_name: String in RunConfig.PRESETS:
		config.apply_preset(preset_name)
		assert_eq(config.difficulty_name(), preset_name, "preset values sit on slider steps")


func test_network_round_trip_and_junk_is_ignored() -> void:
	var config := RunConfig.new()
	config.single_stage = true
	config.stage = 3
	config.boss_enabled = false
	config.set_value("xp_rate", 2.0)
	var copy := RunConfig.from_dict(config.to_dict())
	assert_eq(copy.to_dict(), config.to_dict())
	var junk := RunConfig.from_dict({"stage": 99, "single_stage": "yes", "enemy_health": "lots", "hack": 1})
	assert_eq(junk.stage, 3, "clamped")
	assert_false(junk.single_stage, "wrong type ignored")
	assert_eq(junk.enemy_health, 1.0)


func test_single_stage_run_shape() -> void:
	var config := RunConfig.new()
	assert_eq(config.stage_count(), Stages.ALL.size())
	assert_eq(config.first_stage(), 1)
	config.single_stage = true
	config.stage = 2
	assert_eq(config.stage_count(), 1)
	assert_eq(config.first_stage(), 2)
	assert_string_contains(config.summary(), Stages.get_stage(2).title)


# --- Arena ---

func test_difficulty_scales_enemies_bosses_and_hp() -> void:
	var config := RunConfig.new()
	config.set_value("enemy_health", 2.0)
	config.set_value("boss_health", 0.5)
	config.set_value("hp_bonus", 20)
	var arena: Arena = await _arena_with(config)
	var shambler := EnemyTypes.get_type(EnemyTypes.Id.SHAMBLER)
	assert_eq(arena._scaled_hp(EnemyTypes.Id.SHAMBLER), shambler.max_hp * 2)
	var boss_id := Stages.get_stage(1).boss_type
	assert_eq(arena._scaled_hp(boss_id), roundi(EnemyTypes.get_type(boss_id).max_hp * 0.5))
	var player := arena._player_by_id(1)
	assert_eq(player.health.max_hp, Characters.get_character(player.character_id).max_hp + 20)


func test_single_stage_on_a_later_map_is_won_in_one_stage() -> void:
	var config := RunConfig.new()
	config.single_stage = true
	config.stage = 3
	config.set_value("wave_seconds", 60.0)
	var arena: Arena = await _arena_with(config)
	assert_eq(arena._stage, 3, "plays the chosen map")
	assert_eq(arena._run_depth(), 1, "but with first-stage toughness")
	assert_eq(arena._wave_duration, 60.0)
	assert_eq(arena._scaled_hp(EnemyTypes.Id.SHAMBLER), EnemyTypes.get_type(EnemyTypes.Id.SHAMBLER).max_hp)
	arena._spawn_boss()
	var boss := arena._enemies.find_boss()
	arena._enemies.damage(boss, boss.hp, 1)
	arena._update_phase()
	assert_eq(arena._phase, Arena.Phase.VICTORY)
	assert_eq(arena._final_stats.bosses_defeated, 1)


func test_no_boss_means_surviving_the_timer_wins() -> void:
	var config := RunConfig.new()
	config.single_stage = true
	config.boss_enabled = false
	var arena: Arena = await _arena_with(config)
	arena._elapsed = arena._wave_duration
	arena._update_phase()
	assert_null(arena._enemies.find_boss())
	assert_eq(arena._phase, Arena.Phase.VICTORY)


func test_starting_level_ups_and_weapons() -> void:
	var config := RunConfig.new()
	config.set_value("bonus_levels", 2)
	config.start_with_weapons = true
	var arena: Arena = await _arena_with(config)
	await wait_physics_frames(3)
	assert_eq(arena._phase, Arena.Phase.LEVEL_UP, "starting level-ups are picked right away")
	assert_eq(arena._team.level, 3)
	assert_eq(arena._player_by_id(1).weapon_levels.size(), AutoWeapons.PICKUPS.size())


func test_xp_rate_makes_levels_cheaper() -> void:
	var config := RunConfig.new()
	config.set_value("xp_rate", 2.0)
	var arena: Arena = await _arena_with(config)
	assert_eq(arena._team.add_xp(TeamProgress.xp_to_next(1) / 2), 1)


# --- Lobby pages ---

func test_difficulty_page_presets_and_read_only() -> void:
	var page := DifficultyScreen.new()
	add_child_autofree(page)
	watch_signals(page)
	page.open()
	var buttons: Array = page.list.find_children("*", "Button", true, false)
	var hard: Button = buttons.filter(func(button: Button) -> bool: return button.text == "Hard")[0]
	hard.pressed.emit()
	assert_eq(page.config.difficulty_name(), "Hard")
	assert_signal_emitted(page, "config_changed")
	var sliders: Array = page.list.find_children("*", "HSlider", true, false)
	assert_eq(sliders.size(), 6)
	var viewer := DifficultyScreen.new()
	viewer.editable = false
	add_child_autofree(viewer)
	viewer.open()
	for slider: HSlider in viewer.list.find_children("*", "HSlider", true, false):
		assert_false(slider.editable)


func test_custom_game_page_cycles_mode_and_map() -> void:
	var page := CustomGameScreen.new()
	add_child_autofree(page)
	page.open()
	var buttons: Array = page.list.find_children("*", "Button", true, false)
	(buttons[0] as Button).pressed.emit()
	assert_true(page.config.single_stage)
	(buttons[1] as Button).pressed.emit()
	assert_eq(page.config.stage, 2)
	assert_string_contains((buttons[1] as Button).text, Stages.get_stage(2).title)
