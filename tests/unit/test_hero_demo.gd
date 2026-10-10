extends GutTest
## Hero names and the hero picker's Watch demo (HeroDemo).


func _demo(character: int) -> HeroDemo:
	var demo := HeroDemo.new()
	demo.custom_minimum_size = HeroDemoPopup.DEMO_SIZE
	demo.character_id = character
	add_child_autofree(demo)
	return demo


func test_every_hero_has_their_own_name() -> void:
	var names: Dictionary[String, bool] = {}
	for stats: CharacterStats in Characters.ALL:
		assert_false(stats.hero_name.is_empty(), stats.display_name)
		names[stats.hero_name] = true
	assert_eq(names.size(), Characters.ALL.size(), "no two heroes share a name")
	assert_eq(Characters.get_character(Characters.Id.WANDERER).full_name(), "Kael the Wanderer")


func test_every_hero_kills_shamblers_with_their_weapon() -> void:
	for character: int in Characters.ALL.size():
		var demo := _demo(character)
		demo.seek(HeroDemo.DODGE_START)
		assert_gt(demo.kills, 0, Characters.get_character(character).hero_name)
		assert_eq(demo.part(), HeroDemo.Part.DODGE)


func test_the_hero_steps_out_of_the_bullet_fan() -> void:
	for character: int in Characters.ALL.size():
		var demo := _demo(character)
		demo.seek(HeroDemo.DODGE_START + 0.05)
		var before := demo._hero
		demo.seek(HeroDemo.DODGE_AT + HeroDemo.DODGE_ARRIVE)
		assert_gt(demo._hero.distance_to(before), 10.0, Characters.get_character(character).hero_name)


func test_the_demo_loops_and_is_the_same_every_time() -> void:
	var demo := _demo(Characters.Id.HEXBLADE_WITCH)
	demo.seek(3.0)
	var first := demo.kills
	demo.seek(3.0)
	assert_eq(demo.kills, first, "seek replays the same loop")
	demo.seek(HeroDemo.LOOP_SECONDS + 0.5)
	assert_eq(demo.part(), HeroDemo.Part.WEAPON, "back to the start after a loop")
