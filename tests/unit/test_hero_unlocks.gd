extends GutTest
## Heroes unlock one at a time: start with Kael, win a full run as a hero to
## unlock the next (HeroUnlocks).

const TEST_PATH: String = "user://test_unlocks.cfg"


func before_each() -> void:
	HeroUnlocks.path = TEST_PATH
	HeroUnlocks.ignore_autopilot = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	HeroUnlocks.path = HeroUnlocks.PATH
	HeroUnlocks.ignore_autopilot = false


func test_only_the_wanderer_at_first() -> void:
	assert_eq(HeroUnlocks.unlocked_count(), 1)
	assert_true(HeroUnlocks.is_unlocked(Characters.Id.WANDERER))
	for id: int in range(1, Characters.ALL.size()):
		assert_false(HeroUnlocks.is_unlocked(id), "hero %d starts locked" % id)


func test_each_win_unlocks_the_next_hero_in_order() -> void:
	for id: int in range(0, Characters.ALL.size() - 1):
		assert_eq(HeroUnlocks.record_win(id), id + 1)
		assert_true(HeroUnlocks.is_unlocked(id + 1))
	assert_eq(HeroUnlocks.record_win(Characters.ALL.size() - 1), -1, "the last hero unlocks nothing")
	assert_eq(HeroUnlocks.unlocked_count(), Characters.ALL.size())


func test_winning_again_with_an_earlier_hero_unlocks_nothing() -> void:
	HeroUnlocks.record_win(0)
	HeroUnlocks.record_win(1)
	assert_eq(HeroUnlocks.record_win(0), -1)
	assert_eq(HeroUnlocks.unlocked_count(), 3, "no going back either")


func test_only_a_won_full_run_counts() -> void:
	var config := RunConfig.new()
	assert_true(HeroUnlocks.run_counts(true, config))
	assert_false(HeroUnlocks.run_counts(false, config), "a lost run")
	config.single_stage = true
	assert_false(HeroUnlocks.run_counts(true, config), "a single-stage custom game")


func test_hint_names_the_hero_to_win_with() -> void:
	assert_eq(HeroUnlocks.hint(1), "Win a run as %s to unlock" % Characters.get_character(0).hero_name)
	assert_eq(HeroUnlocks.hint(0), "")
