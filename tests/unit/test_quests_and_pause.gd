extends GutTest
## Shop quests (offers, picks, tracking, rewards) and the host pause.

const ARENA_SCENE: PackedScene = preload("res://src/arena/arena.tscn")


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- Data and tracking ---

func test_quest_tables_line_up() -> void:
	var count := Quests.TITLES.size()
	for table: Array in [Quests.DESCRIPTIONS, Quests.TARGETS, Quests.REWARDS, Quests.ICONS, Quests.CO_OP_ONLY]:
		assert_eq(table.size(), count)
	for id: int in count:
		assert_true(PixelArt.has_sprite(Quests.ICONS[id]), Quests.TITLES[id])
		assert_false(Quests.description(id).contains("%"), "target filled in")


func test_offers_are_three_different_and_solo_skips_co_op_quests() -> void:
	for seed_value: int in 50:
		var offers := Quests.roll_offers(_rng(seed_value), false)
		assert_eq(offers.size(), Quests.OFFERS_PER_SHOP)
		assert_false(offers.has(Quests.Id.GUARDIAN), "no reviving alone")
		var unique: Dictionary[int, bool] = {}
		for id: int in offers:
			unique[id] = true
		assert_eq(unique.size(), offers.size())


func test_tracker_finishes_once() -> void:
	var tracker := QuestTracker.new()
	tracker.assign(5, Quests.Id.SLAYER)
	assert_false(tracker.count(5, Quests.Id.RITUALIST), "other quests don't count")
	assert_false(tracker.count(6, Quests.Id.SLAYER), "other players don't count")
	assert_false(tracker.count(5, Quests.Id.SLAYER, Quests.TARGETS[Quests.Id.SLAYER] - 1))
	assert_true(tracker.count(5, Quests.Id.SLAYER), "the last kill finishes it")
	assert_false(tracker.count(5, Quests.Id.SLAYER), "and only once")
	assert_eq(tracker.shown_progress(5), Quests.TARGETS[Quests.Id.SLAYER])


func test_untouchable_progress_can_reset() -> void:
	var tracker := QuestTracker.new()
	tracker.assign(1, Quests.Id.UNTOUCHABLE)
	tracker.count(1, Quests.Id.UNTOUCHABLE, 30.5)
	assert_eq(tracker.shown_progress(1), 30)
	tracker.set_progress(1, Quests.Id.UNTOUCHABLE, 0.0)
	assert_eq(tracker.shown_progress(1), 0)


func test_shop_quest_picks_and_the_random_fallback() -> void:
	var session := ShopSession.new()
	var relics: Dictionary[int, Array] = {1: [0, 1], 2: [2, 3]}
	var quests: Dictionary[int, Array] = {1: [Quests.Id.SLAYER, Quests.Id.ARSENAL, Quests.Id.RITUALIST],
		2: [Quests.Id.SCAVENGER, Quests.Id.GOLD_DIGGER, Quests.Id.THIEF_CATCHER]}
	session.start(relics, quests)
	assert_false(session.choose_quest(1, Quests.Id.SCAVENGER), "not one of your offers")
	assert_true(session.choose_quest(1, Quests.Id.ARSENAL))
	assert_true(session.choose_quest(1, Quests.Id.SLAYER), "can change your mind")
	session.mark_ready(1)
	assert_false(session.choose_quest(1, Quests.Id.RITUALIST), "not after Ready")
	var final := session.final_quests(_rng())
	assert_eq(final[1], Quests.Id.SLAYER)
	assert_true(quests[2].has(final[2]), "no pick: a random offer")


# --- In a real (solo) arena ---

func _arena() -> Arena:
	Net.start_solo()
	var arena: Arena = ARENA_SCENE.instantiate()
	add_child_autofree(arena)
	await wait_process_frames(2)
	return arena


func test_finishing_a_quest_pays_right_away() -> void:
	var arena := await _arena()
	var player := arena._player_by_id(1)
	var coins_before := player.coins
	arena._start_quests({1: Quests.Id.SCAVENGER})
	assert_eq(player.quest_id, Quests.Id.SCAVENGER)
	arena._on_power_up_collected(PowerUps.Kind.HEART, 1)
	assert_eq(player.coins, coins_before)
	arena._on_power_up_collected(PowerUps.Kind.HEART, 1)
	assert_eq(player.coins, coins_before + Quests.REWARDS[Quests.Id.SCAVENGER])
	assert_string_contains(arena._quest_text(player), "Quest done")


func test_relic_quests_give_a_relic() -> void:
	var arena := await _arena()
	var player := arena._player_by_id(1)
	arena._start_quests({1: Quests.Id.GOLD_DIGGER})
	arena._on_coin_collected(Quests.TARGETS[Quests.Id.GOLD_DIGGER], 1)
	assert_eq(player.relic_ids.size(), 1)


func test_champion_chest_gives_a_weapon() -> void:
	var arena := await _arena()
	var player := arena._player_by_id(1)
	arena._on_chest_opened(1, Vector2(100, 100))
	assert_eq(player.weapon_levels.size(), 1)


func test_ritual_reward_heals_and_drops_xp() -> void:
	var arena := await _arena()
	var player := arena._player_by_id(1)
	player.health.hearts = 1
	var gems_before := arena._gems.count()
	var inside: Array[int] = [1]
	arena._on_ritual_completed(Vector2(400, 400), inside)
	assert_eq(player.health.hearts, 1 + Arena.RITUAL_HEAL)
	assert_gt(arena._gems.count(), gems_before)
	assert_gte(arena._gems.total_value(), roundi(TeamProgress.xp_to_next(1) * Arena.RITUAL_XP_SHARE) - 1)


func test_heart_power_up_heals_and_bomb_clears_around() -> void:
	var arena := await _arena()
	var player := arena._player_by_id(1)
	player.health.hearts = 1
	arena._on_power_up_collected(PowerUps.Kind.HEART, 1)
	assert_eq(player.health.hearts, 2)
	var shambler := arena._enemies.spawn(EnemyTypes.Id.SHAMBLER, player.state.position + Vector2(100, 0))
	arena._on_power_up_collected(PowerUps.Kind.HOLY_BOMB, 1)
	assert_false(shambler.active)


func test_host_pause_freezes_the_game_then_counts_down() -> void:
	var arena := await _arena()
	await wait_physics_frames(3)
	arena.set_host_paused(true)
	var paused_at := arena._elapsed
	await wait_physics_frames(10)
	assert_eq(arena._elapsed, paused_at, "nothing moves while paused")
	arena.set_host_paused(false)
	assert_eq(arena._phase, Arena.Phase.COUNTDOWN, "3, 2, 1 before play resumes")
	assert_almost_eq(arena._resume_left, Arena.RESUME_COUNTDOWN_SECONDS, 0.01)
