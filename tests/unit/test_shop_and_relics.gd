extends GutTest


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _relic_id(title: String) -> int:
	for id: int in Relics.ALL.size():
		if Relics.ALL[id].title == title:
			return id
	return -1


# --- Relic data ---

func test_every_relic_loads_with_effects_and_a_price() -> void:
	for relic: Relic in Relics.ALL:
		assert_gt(relic.effects.size(), 0, relic.title)
		assert_gt(relic.price, 0, relic.title)


func test_offers_are_unowned_and_distinct() -> void:
	var owned: Array[int] = [0, 1]
	for seed_value: int in 30:
		var offers := Relics.roll_offers(_rng(seed_value), owned)
		assert_eq(offers.size(), Relics.OFFERS_PER_SHOP)
		assert_does_not_have(offers, 0)
		assert_does_not_have(offers, 1)
		for id: int in offers:
			assert_eq(offers.count(id), 1)


# --- Relic effects ---

func test_cursed_skull_trades_a_heart_for_damage() -> void:
	var stats := CharacterStats.new()
	var health := PlayerHealth.new()
	health.reset(stats.max_hearts)
	Relics.apply(_relic_id("Cursed Skull"), stats, health)
	assert_eq(stats.bullet_damage, 16)
	assert_eq(stats.max_hearts, 2)
	assert_eq(health.hearts, 2, "current hearts are capped to the new max")


func test_bone_charm_and_holy_water() -> void:
	var stats := CharacterStats.new()
	var health := PlayerHealth.new()
	Relics.apply(_relic_id("Bone Charm"), stats, health)
	Relics.apply(_relic_id("Holy Water"), stats, health)
	assert_eq(stats.pierce, 1)
	assert_almost_eq(stats.ability_power, 1.4, 0.0001)


func test_max_hearts_never_drops_below_one() -> void:
	var stats := CharacterStats.new()
	stats.max_hearts = 1
	var health := PlayerHealth.new()
	health.reset(1)
	Relics.apply(_relic_id("Cursed Skull"), stats, health)
	assert_eq(stats.max_hearts, 1)
	assert_eq(health.hearts, 1)


# --- ShopSession ---

func _session(peers: Array[int]) -> ShopSession:
	var offered: Dictionary[int, Array] = {}
	for peer_id: int in peers:
		offered[peer_id] = [0, 1, 2, 3]
	var session := ShopSession.new()
	session.start(offered)
	return session


func test_can_only_buy_offered_affordable_unowned_relics() -> void:
	var session := _session([1])
	var price := Relics.get_relic(0).price
	var none: Array[int] = []
	assert_true(session.can_buy(1, 0, price, none))
	assert_false(session.can_buy(1, 0, price - 1, none), "too poor")
	var owned: Array[int] = [0]
	assert_false(session.can_buy(1, 0, price, owned), "already owned")
	assert_false(session.can_buy(1, 5, 999, none), "not offered")
	assert_false(session.can_buy(7, 0, 999, none), "not in the shop")


func test_ready_players_cannot_buy_or_reroll() -> void:
	var session := _session([1, 2])
	session.mark_ready(1)
	var none: Array[int] = []
	assert_false(session.can_buy(1, 0, 999, none))
	assert_false(session.can_reroll(1, 999))


func test_shop_waits_for_first_ready_then_counts_down() -> void:
	var session := _session([1, 2])
	session.tick(500.0)
	assert_false(session.is_finished())
	session.mark_ready(1)
	session.tick(ShopSession.COUNTDOWN_SECONDS - 1.0)
	assert_false(session.is_finished())
	assert_eq(session.waiting_for(), [2])
	session.tick(2.0)
	assert_true(session.is_finished())


func test_shop_closes_early_when_everyone_is_ready() -> void:
	var session := _session([1, 2])
	session.mark_ready(1)
	session.mark_ready(2)
	assert_true(session.is_finished())


# --- Kill-heal relic ---

func test_vampire_fang_heals_every_n_kills() -> void:
	var player: Player = preload("res://src/player/player.tscn").instantiate()
	player.setup(1, 0, Vector2(100, 100), Rect2(0, 0, 500, 500))
	add_child_autofree(player)
	player.apply_relic(_relic_id("Vampire Fang"))
	player.health.take_hit(1, 0.0)
	for i: int in 59:
		player.register_kill()
	assert_eq(player.health.hearts, player.health.max_hearts - 1)
	player.register_kill()
	assert_eq(player.health.hearts, player.health.max_hearts)
