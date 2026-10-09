extends GutTest


func test_walk_frames_alternate_only_while_moving() -> void:
	assert_eq(PixelArt.walk_frame("wanderer", false, 3.0), "wanderer")
	assert_eq(PixelArt.walk_frame("wanderer", true, 0.2), "wanderer_walk_1")
	assert_eq(PixelArt.walk_frame("wanderer", true, 1.2), "wanderer_walk_2")
	assert_eq(PixelArt.walk_frame("bone_warden", true, 1.0), "bone_warden", "no walk frames = stays put")


func test_every_hero_has_a_walk_cycle_matching_its_size() -> void:
	for stats: CharacterStats in Characters.ALL:
		for frame: String in ["_walk_1", "_walk_2"]:
			assert_true(PixelArt.has_sprite(stats.sprite + frame), stats.sprite + frame)
			assert_eq(PixelArt.size_of(stats.sprite + frame), PixelArt.size_of(stats.sprite))


func test_every_animation_frame_matches_its_base_size() -> void:
	for sprite: String in PixelArt.SPRITES:
		for suffix: String in ["_walk_1", "_walk_2", "_attack"]:
			if sprite.ends_with(suffix):
				var base := sprite.trim_suffix(suffix)
				assert_eq(PixelArt.size_of(sprite), PixelArt.size_of(base), sprite)


func test_enemy_shows_attack_pose_after_firing() -> void:
	var enemies := EnemyManager.new()
	add_child_autofree(enemies)
	var cultist := enemies.spawn(EnemyTypes.Id.CULTIST, Vector2(100, 100))
	assert_eq(cultist._current_sprite(), "cultist")
	cultist.play_attack()
	assert_eq(cultist._current_sprite(), "cultist_attack")
	cultist._process(Enemy.ATTACK_POSE_SECONDS + 0.1)
	assert_ne(cultist._current_sprite(), "cultist_attack")


func test_death_animation_plays_then_disappears() -> void:
	var effects := EffectsLayer.new()
	add_child_autofree(effects)
	effects.corpse("shambler", Vector2(50, 50), false, 1.0, 0.4)
	assert_eq(effects.corpse_count(), 1)
	effects._process(0.2)
	assert_eq(effects.corpse_count(), 1)
	effects._process(0.3)
	assert_eq(effects.corpse_count(), 0)


func test_coins_have_a_spin_frame() -> void:
	assert_true(PixelArt.has_sprite("coin_1"))
	assert_true(PixelArt.has_sprite("coin_big_1"))
