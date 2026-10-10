extends GutTest
## Embers: light permanent progression (earning, the shrine's boosts, saving,
## and boosts reaching a player's stats).

const TEST_PATH: String = "user://test_embers.cfg"


func before_each() -> void:
	Embers.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Embers.path = Embers.PATH


func test_earning_rewards_progress() -> void:
	var early_death := Embers.earned_for(0, false, 300, 1.0)
	var stage_two := Embers.earned_for(1, false, 800, 1.0)
	var victory := Embers.earned_for(3, true, 2500, 1.0)
	assert_eq(early_death, 3)
	assert_eq(stage_two, 16)
	assert_eq(victory, 3 * Embers.PER_BOSS + Embers.PER_VICTORY + Embers.MAX_KILL_EMBERS, "kill embers are capped")
	assert_lt(Embers.earned_for(3, true, 2500, 0.5), victory, "easier settings earn less")
	assert_eq(Embers.earned_for(3, true, 2500, 100.0), victory * 2, "multiplier capped at 2")


func test_buying_everything_takes_about_a_hundred_runs() -> void:
	var typical_run := Embers.earned_for(1, false, 800, 1.0)
	var runs := float(Embers.full_price()) / typical_run
	assert_between(runs, 80.0, 150.0, "runs to buy everything: %.0f" % runs)


func test_buy_rank_up_and_max() -> void:
	var embers := Embers.new()
	embers.balance = 1000
	assert_true(embers.buy(Embers.Boost.SWIFTNESS))
	assert_eq(embers.ranks[Embers.Boost.SWIFTNESS], 1)
	assert_eq(embers.balance, 1000 - Embers.PRICES[0])
	assert_true(embers.buy(Embers.Boost.SWIFTNESS))
	assert_true(embers.buy(Embers.Boost.SWIFTNESS))
	assert_eq(embers.next_price(Embers.Boost.SWIFTNESS), -1)
	assert_false(embers.buy(Embers.Boost.SWIFTNESS), "maxed")
	embers.balance = 0
	assert_false(embers.buy(Embers.Boost.GREED), "too poor")


func test_refund_gives_everything_back() -> void:
	var embers := Embers.new()
	embers.balance = 500
	embers.buy(Embers.Boost.FOCUS)
	embers.buy(Embers.Boost.FOCUS)
	embers.buy(Embers.Boost.REACH)
	embers.refund_all()
	assert_eq(embers.balance, 500)
	assert_eq(embers.spent(), 0)


func test_switched_off_brings_no_boosts() -> void:
	var embers := Embers.new()
	embers.ranks[Embers.Boost.KEEN_EYE] = 2
	assert_eq(embers.active_ranks()[Embers.Boost.KEEN_EYE], 2)
	embers.enabled = false
	assert_eq(embers.active_ranks()[Embers.Boost.KEEN_EYE], 0)


func test_save_and_load() -> void:
	var embers := Embers.new()
	embers.balance = 42
	embers.total_earned = 99
	embers.ranks[Embers.Boost.RESOLVE] = 3
	embers.enabled = false
	embers.save()
	var loaded := Embers.load_saved()
	assert_eq(loaded.balance, 42)
	assert_eq(loaded.total_earned, 99)
	assert_eq(loaded.ranks[Embers.Boost.RESOLVE], 3)
	assert_false(loaded.enabled)
	var after_run := Embers.add_earned(10)
	assert_eq(after_run.balance, 52)
	assert_eq(Embers.load_saved().total_earned, 109)


func test_untrusted_ranks_are_cleaned() -> void:
	var clean := Embers.clean_ranks(PackedInt32Array([9, -4, 2]))
	assert_eq(clean.size(), Embers.BOOSTS.size())
	assert_eq(clean[0], Embers.MAX_RANK)
	assert_eq(clean[1], 0)
	assert_eq(clean[2], 2)


func test_maxed_boosts_stay_small() -> void:
	var base := Characters.get_character(Characters.Id.HEXBLADE_WITCH).duplicate() as CharacterStats
	var boosted := base.duplicate() as CharacterStats
	var all := PackedInt32Array()
	all.resize(Embers.BOOSTS.size())
	all.fill(Embers.MAX_RANK)
	Embers.apply(all, boosted)
	assert_almost_eq(boosted.move_speed / base.move_speed, 1.06, 0.001)
	assert_almost_eq(boosted.auto_cooldown_scale / base.auto_cooldown_scale, 0.91, 0.001)
	assert_almost_eq(boosted.crit_chance - base.crit_chance, 0.06, 0.001)
	assert_almost_eq(boosted.pickup_radius / base.pickup_radius, 1.18, 0.001)
	assert_almost_eq(boosted.coin_luck, 0.15, 0.001)
	assert_almost_eq(boosted.hit_invulnerability - base.hit_invulnerability, 0.15, 0.001)
	assert_eq(boosted.max_hp, base.max_hp, "no extra HP")


func test_player_spawns_with_its_boosts() -> void:
	var ranks := PackedInt32Array()
	ranks.resize(Embers.BOOSTS.size())
	ranks[Embers.Boost.SWIFTNESS] = 3
	var player: Player = preload("res://src/player/player.tscn").instantiate()
	player.setup(5, 1, Vector2.ZERO, Rect2(0, 0, 100, 100), Characters.Id.WANDERER, 0, ranks)
	var base := Characters.get_character(Characters.Id.WANDERER)
	assert_almost_eq(player.stats.move_speed, base.move_speed * 1.06, 0.01)
	assert_almost_eq(base.move_speed, 121.0, 0.01, "the shared character data is untouched")
	player.free()


func test_host_can_turn_boosts_off_and_it_survives_the_network() -> void:
	var config := RunConfig.new()
	assert_true(config.ember_boosts, "on by default")
	config.ember_boosts = false
	assert_false(RunConfig.from_dict(config.to_dict()).ember_boosts)
	assert_true(RunConfig.from_dict({}).ember_boosts, "old saves keep boosts on")
	assert_string_contains(config.summary(), "no Ember boosts")
