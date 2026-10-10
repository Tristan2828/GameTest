extends GutTest
## Level-up cards (v0.23.0, auto-fire redesign step 2): weapon and passive
## slots, main weapon levels, fillers, altars, chests and evolutions.

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")


func _player(character: int = Characters.Id.WANDERER) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup(1, 0, Vector2(500, 500), Rect2(0, 0, 1600, 1000), character)
	add_child_autofree(player)
	return player


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _max_weapon(player: Player, weapon_id: int) -> void:
	for i: int in AutoWeapons.MAX_LEVEL:
		player.apply_card(Cards.weapon(weapon_id))


func _max_main(player: Player) -> void:
	for i: int in player.stats.main_max_level() - 1:
		player.apply_card(Cards.MAIN_LEVEL)


func test_card_numbers_round_trip() -> void:
	assert_true(Cards.is_upgrade(0))
	assert_eq(Cards.weapon_id(Cards.weapon(AutoWeapons.Id.HOLY_AURA)), AutoWeapons.Id.HOLY_AURA)
	assert_eq(Cards.weapon_id(Cards.evolve(AutoWeapons.Id.SANCTUARY)), AutoWeapons.Id.SANCTUARY)
	assert_true(Cards.is_valid(Cards.MAIN_LEVEL))
	assert_true(Cards.is_valid(Cards.evolve(AutoWeapons.Id.DEATH_SPIRAL)))
	assert_false(Cards.is_valid(Cards.evolve(AutoWeapons.Id.HOLY_AURA)), "not an evolution")
	assert_false(Cards.is_valid(Cards.weapon(999)))
	assert_false(Cards.is_valid(-1))


func test_roll_gives_three_different_cards() -> void:
	var player := _player()
	for seed_value: int in 50:
		var cards := Cards.roll(_rng(seed_value), player, false)
		assert_eq(cards.size(), Cards.CHOICES_PER_LEVEL)
		assert_ne(cards[0], cards[1])
		assert_ne(cards[1], cards[2])
		assert_ne(cards[0], cards[2])
		for card: int in cards:
			assert_true(Cards.can_take(player, card))


func test_a_fresh_hero_is_offered_weapons_passives_and_their_main_weapon() -> void:
	var seen_weapon := false
	var seen_passive := false
	var seen_main := false
	var player := _player()
	for seed_value: int in 100:
		for card: int in Cards.roll(_rng(seed_value), player, false):
			seen_weapon = seen_weapon or Cards.is_weapon(card)
			seen_passive = seen_passive or (Cards.is_upgrade(card) and Upgrades.get_upgrade(card).passive)
			seen_main = seen_main or card == Cards.MAIN_LEVEL
			assert_false(Cards.is_upgrade(card) and Upgrades.get_upgrade(card).retired, "retired upgrade offered")
	assert_true(seen_weapon and seen_passive and seen_main)


func test_full_weapon_slots_only_offer_levels_of_carried_weapons() -> void:
	var player := _player()
	var carried: Array[int] = [AutoWeapons.Id.ORBITING_SKULLS, AutoWeapons.Id.SEEKING_BOLTS, AutoWeapons.Id.HOLY_AURA,
		AutoWeapons.Id.HELLFIRE_TRAIL, AutoWeapons.Id.GRAVE_BLAST]
	for weapon_id: int in carried:
		player.apply_card(Cards.weapon(weapon_id))
	assert_eq(Cards.free_weapon_slots(player), 0)
	assert_false(Cards.can_take(player, Cards.weapon(AutoWeapons.Id.HEX_SNARE)), "no room")
	assert_true(Cards.can_take(player, Cards.weapon(AutoWeapons.Id.HOLY_AURA)), "a level is fine")
	for seed_value: int in 100:
		for card: int in Cards.roll(_rng(seed_value), player, false):
			if Cards.is_weapon(card):
				assert_has(carried, Cards.weapon_id(card))


func test_full_passive_slots_only_offer_levels_of_carried_passives() -> void:
	var player := _player()
	var ids := Upgrades.passive_ids().slice(0, Upgrades.PASSIVE_SLOTS)
	for id: int in ids:
		player.apply_card(id)
	assert_eq(Cards.free_passive_slots(player), 0)
	for seed_value: int in 100:
		for card: int in Cards.roll(_rng(seed_value), player, false):
			if Cards.is_upgrade(card) and Upgrades.get_upgrade(card).passive:
				assert_has(ids, card)


func test_passives_stop_at_their_max_level() -> void:
	var player := _player()
	var id: int = Upgrades.passive_ids()[0]
	for i: int in Upgrades.get_upgrade(id).max_stacks:
		assert_true(Cards.can_take(player, id))
		player.apply_card(id)
	assert_false(Cards.can_take(player, id))
	assert_eq(Cards.passive_levels(player)[id], Upgrades.get_upgrade(id).max_stacks)


func test_a_full_build_gets_fillers() -> void:
	var player := _player()
	_max_main(player)
	for weapon_id: int in AutoWeapons.PICKUPS.slice(0, AutoWeapons.WEAPON_SLOTS - 1):
		_max_weapon(player, weapon_id)
	for id: int in Upgrades.passive_ids().slice(0, Upgrades.PASSIVE_SLOTS):
		for i: int in Upgrades.get_upgrade(id).max_stacks:
			player.apply_card(id)
	# Evolutions that became ready aren't level-up cards.
	assert_true(Cards.options(player).is_empty())
	assert_eq(Cards.roll(_rng(1), player, true), [Cards.HEAL_FILLER, Cards.COIN_FILLER])
	assert_eq(Cards.roll(_rng(1), player, false), [Cards.COIN_FILLER])


func test_coin_pouch_pays_the_player() -> void:
	var player := _player()
	player.apply_card(Cards.COIN_FILLER)
	assert_eq(player.coins, roundi(Upgrades.get_upgrade(Cards.COIN_FILLER).amount))


func test_main_weapon_levels_apply_the_heros_steps() -> void:
	var player := _player(Characters.Id.WANDERER)
	assert_eq(player.main_level, 1)
	var bolts := player.stats.projectile_count
	player.apply_card(Cards.MAIN_LEVEL)  # Level 2: Extra Bolt
	assert_eq(player.main_level, 2)
	assert_eq(player.stats.projectile_count, bolts + 1)
	_max_main(player)
	assert_eq(player.main_level, player.stats.main_max_level())
	assert_false(Cards.can_take(player, Cards.MAIN_LEVEL))
	player.apply_card(Cards.MAIN_LEVEL)
	assert_eq(player.main_level, player.stats.main_max_level(), "no level past the max")


func test_main_weapon_evolves_with_its_passive() -> void:
	var player := _player(Characters.Id.WANDERER)
	_max_main(player)
	assert_does_not_have(Cards.ready_evolutions(player), Cards.MAIN_EVOLUTION, "needs the passive too")
	player.apply_card(player.stats.evolution_catalyst)
	assert_has(Cards.ready_evolutions(player), Cards.MAIN_EVOLUTION)
	var damage := player.stats.bullet_damage
	player.apply_card(Cards.MAIN_EVOLUTION)
	assert_true(player.main_evolved)
	assert_eq(player.stats.main_weapon_name, "Storm Bolter")
	assert_gt(player.stats.bullet_damage, damage)
	assert_true(Cards.ready_evolutions(player).is_empty(), "only once")


func test_auto_weapon_evolves_in_its_slot() -> void:
	var player := _player()
	player.apply_card(Cards.weapon(AutoWeapons.Id.SEEKING_BOLTS))
	_max_weapon(player, AutoWeapons.Id.HOLY_AURA)
	player.apply_card(Cards.weapon(AutoWeapons.Id.HEX_SNARE))
	assert_true(Cards.ready_evolutions(player).is_empty())
	player.apply_card(AutoWeapons.get_weapon(AutoWeapons.Id.SANCTUARY).catalyst)
	var card := Cards.evolve(AutoWeapons.Id.SANCTUARY)
	assert_eq(Cards.ready_evolutions(player), [card])
	player.apply_card(card)
	assert_eq(player.weapon_levels.keys(), [AutoWeapons.Id.SEEKING_BOLTS, AutoWeapons.Id.SANCTUARY, AutoWeapons.Id.HEX_SNARE])
	assert_false(Cards.can_take(player, Cards.weapon(AutoWeapons.Id.HOLY_AURA)), "the base can't come back")
	assert_true(Cards.ready_evolutions(player).is_empty())


func test_every_evolution_names_a_real_base_and_passive() -> void:
	for evolved: int in AutoWeapons.EVOLUTIONS:
		var weapon := AutoWeapons.get_weapon(evolved)
		assert_true(weapon.is_evolution(), weapon.title)
		assert_has(AutoWeapons.PICKUPS, weapon.evolves_from, weapon.title)
		assert_has(Upgrades.passive_ids(), weapon.catalyst, weapon.title)
		assert_eq(AutoWeapons.evolution_of(weapon.evolves_from), evolved)
		assert_gt(weapon.damage_at(1), AutoWeapons.get_weapon(weapon.evolves_from).damage_at(AutoWeapons.MAX_LEVEL),
			weapon.title + " hits harder than its maxed base")
	for stats: CharacterStats in Characters.ALL:
		assert_not_null(stats.evolution, stats.hero_name)
		assert_has(Upgrades.passive_ids(), stats.evolution_catalyst, stats.hero_name)
		assert_true(PixelArt.has_sprite(stats.evolved_weapon_icon), stats.evolved_weapon_name)


func test_altar_gives_its_weapon_or_a_level_of_one_you_carry() -> void:
	var player := _player()
	assert_eq(Cards.altar_card(_rng(1), player, AutoWeapons.Id.HOLY_AURA), Cards.weapon(AutoWeapons.Id.HOLY_AURA))
	_max_weapon(player, AutoWeapons.Id.HOLY_AURA)
	assert_eq(Cards.altar_card(_rng(1), player, AutoWeapons.Id.HOLY_AURA), Cards.MAIN_LEVEL, "maxed: the main weapon")
	_max_main(player)
	assert_eq(Cards.altar_card(_rng(1), player, AutoWeapons.Id.HOLY_AURA), -1, "nothing left: coins")


func test_chest_prefers_a_ready_evolution() -> void:
	var player := _player()
	_max_weapon(player, AutoWeapons.Id.ORBITING_SKULLS)
	player.apply_card(AutoWeapons.get_weapon(AutoWeapons.Id.DEATH_SPIRAL).catalyst)
	assert_eq(Cards.chest_card(_rng(3), player), Cards.evolve(AutoWeapons.Id.DEATH_SPIRAL))


func test_cards_show_a_title_icon_and_preview() -> void:
	var player := _player(Characters.Id.HEXBLADE_WITCH)
	var cards: Array[int] = [Cards.MAIN_LEVEL, Cards.weapon(AutoWeapons.Id.SPIRIT_DAGGERS), 0, Cards.COIN_FILLER]
	for card: int in cards:
		assert_ne(Cards.title(card, player.stats), "", str(card))
		assert_true(PixelArt.has_sprite(Cards.icon(card, player.stats)), str(card))
		assert_ne(Cards.preview_text(card, player), "", str(card))
	assert_eq(Cards.title(Cards.MAIN_LEVEL, player.stats), "Chain Lightning")
	assert_eq(Cards.badge(Cards.weapon(AutoWeapons.Id.SPIRIT_DAGGERS), player), "New weapon!")
	player.apply_card(Cards.weapon(AutoWeapons.Id.SPIRIT_DAGGERS))
	assert_eq(Cards.badge(Cards.weapon(AutoWeapons.Id.SPIRIT_DAGGERS), player), "")
	assert_eq(Cards.levels(Cards.weapon(AutoWeapons.Id.SPIRIT_DAGGERS), player), Vector2i(1, AutoWeapons.MAX_LEVEL))


func test_same_cards_build_the_same_hero_on_every_peer() -> void:
	var cards: Array[int] = [Cards.MAIN_LEVEL, 0, Cards.weapon(AutoWeapons.Id.HOLY_AURA), 1, Cards.MAIN_LEVEL, 0]
	var a := _player(Characters.Id.NECROMANCER)
	var b := _player(Characters.Id.NECROMANCER)
	for card: int in cards:
		a.apply_card(card)
	for card: int in a.card_history:
		b.apply_card(card)
	assert_eq(b.stats.bullet_damage, a.stats.bullet_damage)
	assert_eq(b.stats.projectile_count, a.stats.projectile_count)
	assert_eq(b.weapon_levels, a.weapon_levels)
	assert_eq(b.main_level, a.main_level)
