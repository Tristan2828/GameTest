extends GutTest
## Runs a real arena in solo mode (the test runner's default offline peer acts
## as the host) to check the stage flow end to end.

const ARENA_SCENE: PackedScene = preload("res://src/arena/arena.tscn")

var _arena: Arena


func before_each() -> void:
	Net.start_solo()
	_arena = ARENA_SCENE.instantiate()
	add_child_autofree(_arena)
	await wait_process_frames(2)


func _local_player() -> Player:
	return _arena._player_by_id(1)


func test_solo_arena_spawns_the_local_player() -> void:
	assert_not_null(_local_player())
	assert_eq(_arena._phase, Arena.Phase.PLAYING)


func test_boss_arrives_after_the_waves() -> void:
	_arena._elapsed = _arena._wave_duration
	_arena._update_phase()
	var boss := _arena._enemies.find_boss()
	assert_not_null(boss)
	assert_eq(boss.max_hp, EnemyTypes.get_type(EnemyTypes.Id.BONE_WARDEN).max_hp, "solo: no HP scaling")


func test_killing_the_boss_clears_the_stage() -> void:
	_arena._spawn_boss()
	var boss := _arena._enemies.find_boss()
	_arena._enemies.damage(boss, boss.hp, 1)
	_arena._update_phase()
	assert_eq(_arena._phase, Arena.Phase.STAGE_CLEAR)
	assert_eq(_arena._enemies.active_count(), 0)


func test_boss_attacks_fire_enemy_bullets() -> void:
	_arena._spawn_boss()
	for i: int in 60 * 4:
		_arena._tick_boss(1.0 / 60.0)
	_arena._enemy_bullets.step(0.0)
	assert_gt(_arena._enemy_bullets.count(), 0)


func test_everyone_down_ends_the_run() -> void:
	_local_player().health.take_bullet(9999, 1.0)
	_arena._update_phase()
	assert_eq(_arena._phase, Arena.Phase.RUN_OVER)


func test_level_up_pauses_until_pick_then_applies_upgrade() -> void:
	_arena._on_gem_collected(TeamProgress.xp_to_next(1), 1)
	await wait_physics_frames(2)
	assert_eq(_arena._phase, Arena.Phase.LEVEL_UP)
	var clock := _arena._elapsed
	await wait_physics_frames(10)
	assert_eq(_arena._elapsed, clock, "the stage clock is frozen during the pause")
	var choice: int = _arena._level_up._my_choices[0]
	_arena._level_up._pick_locally(choice)
	await wait_physics_frames(2)
	assert_eq(_arena._phase, Arena.Phase.PLAYING, "solo resumes right away (no 3, 2, 1)")
	assert_eq(_local_player().upgrade_ids, [choice])


func _clear_current_stage() -> void:
	_arena._spawn_boss()
	var boss := _arena._enemies.find_boss()
	_arena._enemies.damage(boss, boss.hp, 1)
	_arena._update_phase()


func test_stage_clear_leads_to_next_stage_with_everyone_respawned() -> void:
	var player := _local_player()
	_clear_current_stage()
	assert_eq(_arena._phase, Arena.Phase.STAGE_CLEAR)
	# (In solo, going down would end the run; here we just check downed players respawn.)
	player.health.take_bullet(9999, 0.0)
	assert_true(player.is_downed())
	await wait_seconds(Arena.STAGE_CLEAR_DELAY + 0.3)
	_arena._shop._ready_locally()
	await wait_physics_frames(2)
	assert_eq(_arena._phase, Arena.Phase.PLAYING, "solo starts the next stage right away")
	assert_eq(_arena._stage, 2)
	assert_false(player.is_downed(), "downed players get back up")
	assert_eq(player.health.hp, player.health.max_hp)
	assert_almost_eq(_arena._elapsed, 0.0, 0.5)


func test_run_progress_carries_over_between_stages() -> void:
	_arena._team.add_xp(3)
	_local_player().apply_upgrade(0)
	_clear_current_stage()
	_arena._begin_next_stage()
	assert_eq(_arena._team.xp, 3)
	assert_eq(_local_player().upgrade_ids, [0])


func test_beating_the_last_boss_is_victory() -> void:
	_arena._stage = Arena.STAGE_COUNT
	_clear_current_stage()
	assert_eq(_arena._phase, Arena.Phase.VICTORY)


func test_later_stages_have_tougher_enemies() -> void:
	var base := EnemyTypes.get_type(EnemyTypes.Id.SHAMBLER).max_hp
	assert_eq(_arena._scaled_hp(EnemyTypes.Id.SHAMBLER), base)
	_arena._stage = 3
	assert_eq(_arena._scaled_hp(EnemyTypes.Id.SHAMBLER), roundi(base * Arena.ENEMY_HP_BY_DEPTH[2]))
	var boss_id := Stages.get_stage(3).boss_type
	assert_eq(_arena._scaled_hp(boss_id), roundi(EnemyTypes.get_type(boss_id).max_hp * Arena.BOSS_HP_BY_DEPTH[2]))
	assert_gt(Arena.ENEMY_HP_BY_DEPTH[2], Arena.ENEMY_HP_BY_DEPTH[1], "each stage is tougher than the last")


func test_later_stages_start_their_spawn_ramp_ahead() -> void:
	_arena._stage = 2
	_arena._setup_stage()
	assert_eq(_arena._director.ramp_head_start, Arena.RAMP_HEAD_START_BY_DEPTH[1])


func test_downed_player_cant_move_or_attack() -> void:
	var player := _local_player()
	player.health.take_bullet(9999, 0.0)
	watch_signals(player)
	var start := player.state.position
	for i: int in 30:
		var input := PlayerInput.new()
		input.move = Vector2.RIGHT
		input.fire = true
		player._simulate(input, 1.0 / 60.0)
	assert_eq(player.state.position, start, "lies still until revived")
	assert_signal_not_emitted(player, "shot_requested")
	assert_false(player.can_be_shot())


func test_downed_players_still_pull_in_nearby_gems() -> void:
	var player := _local_player()
	player.health.take_bullet(9999, 0.0)
	_arena._gems.spawn_host(player.state.position + Vector2(10, 0), 3)
	for i: int in 30:
		_arena._tick_gems(1.0 / 60.0, true)
	assert_eq(_arena._gems.count(), 0)
	assert_eq(_arena._team.xp, 3)


func test_stage_clear_opens_shop_then_next_stage() -> void:
	_clear_current_stage()
	await wait_seconds(Arena.STAGE_CLEAR_DELAY + 0.3)
	assert_eq(_arena._phase, Arena.Phase.SHOP)
	assert_true(_arena._shop.is_open_locally())
	_arena._shop._ready_locally()
	await wait_physics_frames(2)
	assert_eq(_arena._phase, Arena.Phase.PLAYING, "solo starts the next stage right away")
	assert_eq(_arena._stage, 2)


func test_buying_in_the_shop_spends_coins_and_applies_relic() -> void:
	var player := _local_player()
	_clear_current_stage()
	await wait_seconds(Arena.STAGE_CLEAR_DELAY + 0.3)
	player.coins = 100
	var relic_id: int = _arena._shop._my_offers[0]
	_arena._shop._buy_locally(relic_id)
	assert_eq(player.relic_ids, [relic_id])
	assert_eq(player.coins, 100 - Relics.get_relic(relic_id).price)
	_arena._shop._buy_locally(relic_id)
	assert_eq(player.relic_ids, [relic_id], "can't buy the same relic twice")


func test_stage_clear_pays_bounty_and_banks_leftover_pickups() -> void:
	var player := _local_player()
	_arena._gems.spawn_host(Vector2(5, 5), 4)
	_arena._coins.spawn_host(Vector2(5, 5), 3)
	_clear_current_stage()
	assert_eq(player.coins, 3 + Arena.BOSS_BOUNTY)
	assert_eq(_arena._team.xp, 4)


func test_killed_enemies_sometimes_drop_coins() -> void:
	for i: int in 100:
		var enemy := _arena._enemies.spawn(EnemyTypes.Id.GHOUL, Vector2(300 + i, 300))
		_arena._enemies.damage(enemy, enemy.hp, 1)
	assert_between(_arena._coins.count(), 6, 40, "Ghouls drop coins about a fifth of the time")


func test_run_end_shows_stats_table() -> void:
	var player := _local_player()
	_arena._run_stats.add(1, RunStats.Stat.KILLS, 12)
	var hp := player.health.hp
	player.take_bullet(9999)
	_arena._update_phase()
	assert_eq(_arena._phase, Arena.Phase.RUN_OVER)
	var stats: RunStats = _arena._final_stats
	assert_not_null(stats)
	assert_eq(stats.get_stat(1, RunStats.Stat.KILLS), 12)
	assert_eq(stats.get_stat(1, RunStats.Stat.DOWNS), 1)
	assert_eq(stats.get_stat(1, RunStats.Stat.HP_LOST), hp)
	assert_false(stats.victory)
	assert_eq(stats.stage_reached, 1)
	assert_true(_arena._hud.run_summary.visible, "run summary screen is shown")


func test_run_summary_button_returns_to_character_select_once() -> void:
	_local_player().take_bullet(9999)
	_arena._update_phase()
	var buttons: Array[Button] = []
	for node: Node in _arena._hud.run_summary.find_children("*", "Button", true, false):
		if (node as Button).text.begins_with("Return"):
			buttons.append(node as Button)
	assert_eq(buttons.size(), 1, "the host gets a return button")
	watch_signals(_arena)
	buttons[0].pressed.emit()
	buttons[0].pressed.emit()
	assert_signal_emit_count(_arena, "restart_requested", 1)


func test_run_end_names_the_boss_that_won() -> void:
	_arena._spawn_boss()
	_local_player().take_bullet(9999)
	_arena._update_phase()
	assert_eq(_arena._final_stats.fell_to, EnemyTypes.get_type(Stages.get_stage(1).boss_type).display_name)


# --- The old hero abilities, now auto weapons anyone can find ---

func test_hex_snare_roots_enemies_and_they_take_extra_damage() -> void:
	var player := _local_player()
	var hex := AutoWeapons.get_weapon(AutoWeapons.Id.HEX_SNARE)
	var at := player.state.position + Vector2(80.0, 0.0)
	var enemy := _arena._enemies.spawn(0, at)
	var far := _arena._enemies.spawn(0, at + Vector2(400.0, 0.0))
	_arena._enemies.rebuild_grid()
	_arena._on_ability_cast(player, AutoWeapons.Id.HEX_SNARE, 1, at)
	assert_true(enemy.hexed, "enemy in the sigil is hexed")
	assert_false(far.hexed, "enemy outside is not")
	var targets: Array[Vector2] = [player.state.position]
	_arena._enemies.tick_host(0.5, targets)
	assert_almost_eq(enemy.position.x, at.x, 0.5, "rooted enemies don't move")
	var hp_before := enemy.hp
	_arena._enemies.damage(enemy, 4, 1)
	assert_eq(hp_before - enemy.hp, roundi(4 * AutoWeapons.HEX_DAMAGE_MULTIPLIER))
	_arena._enemies.tick_host(hex.duration, targets)
	assert_false(enemy.hexed, "the hex wears off")


func test_bone_effigy_lures_enemies_then_bursts() -> void:
	var player := _local_player()
	var effigy := AutoWeapons.get_weapon(AutoWeapons.Id.BONE_EFFIGY)
	_arena._on_ability_cast(player, AutoWeapons.Id.BONE_EFFIGY, 1, player.state.position + Vector2(40.0, 0.0))
	assert_eq(_arena._effigies.size(), 1)
	var effigy_at: Vector2 = _arena._effigies[0].position
	# An enemy on the far side of the effigy walks toward it, away from the player.
	var enemy := _arena._enemies.spawn(0, effigy_at + Vector2(60.0, 0.0))
	_arena._enemies.rebuild_grid()
	var start := enemy.position
	_arena._enemies.tick_host(0.2, [player.state.position] as Array[Vector2], _arena._effigy_positions(), _arena._effigy_lure_radius())
	assert_lt(enemy.position.distance_to(effigy_at), start.distance_to(effigy_at), "lured toward the effigy")
	var hp_before := enemy.hp
	enemy.position = effigy_at + Vector2(10.0, 0.0)
	_arena._enemies.rebuild_grid()
	_arena._tick_effigies(effigy.duration + 0.1)
	assert_eq(_arena._effigies.size(), 0, "effigy is gone after bursting")
	assert_true(not enemy.active or enemy.hp < hp_before, "the burst hurt the enemy")



func test_grave_blast_heals_protects_and_clears_bullets() -> void:
	var player := _local_player()
	player.health.hp = 10
	var at := player.state.position
	_arena._enemy_bullets.spawn(at + Vector2(30, 0), Vector2.ZERO, 15, 5.0, 0, 0, 0.0)
	var enemy := _arena._enemies.spawn(0, at + Vector2(20, 0))
	_arena._enemies.rebuild_grid()
	_arena._on_ability_cast(player, AutoWeapons.Id.GRAVE_BLAST, 1, at)
	assert_gt(player.health.hp, 10, "heals a share of max HP")
	assert_true(player.health.is_invulnerable())
	assert_eq(_arena._enemy_bullets.count(), 0, "nearby enemy bullets are wiped out")
	assert_true(not enemy.active or enemy.hp < enemy.max_hp)


func test_ability_weapons_fire_by_themselves_at_a_crowd() -> void:
	var player := _local_player()
	player.gain_weapon(AutoWeapons.Id.HEX_SNARE)
	var crowd := player.state.position + Vector2(70, 0)
	for i: int in 5:
		_arena._enemies.spawn(0, crowd + Vector2(i * 3, 0))
	_arena._enemies.rebuild_grid()
	watch_signals(_arena._weapons)
	for i: int in 60 * 8:
		_arena._weapons.tick_host(1.0 / 60.0, 1.0, _arena._player_nodes(), _arena._enemies, [])
	assert_signal_emitted(_arena._weapons, "ability_cast")
	var args: Array = get_signal_parameters(_arena._weapons, "ability_cast")
	assert_lt((args[3] as Vector2).distance_to(crowd + Vector2(6, 0)), 12.0, "aimed at the crowd")


func test_touching_enemies_drain_hp_and_bullets_give_bullet_safety() -> void:
	var player := _local_player()
	var max_hp := player.health.max_hp
	var shambler := EnemyTypes.get_type(EnemyTypes.Id.SHAMBLER)
	_arena._enemies.spawn(EnemyTypes.Id.SHAMBLER, player.state.position)
	_arena._enemies.spawn(EnemyTypes.Id.SHAMBLER, player.state.position + Vector2(1, 0))
	_arena._enemies.rebuild_grid()
	_arena._apply_contact_damage()
	assert_eq(player.health.hp, max_hp - 2 * shambler.contact_damage, "two Shamblers drain together")
	_arena._apply_contact_damage()
	assert_eq(player.health.hp, max_hp - 2 * shambler.contact_damage, "only every half second")
	player.health.tick(PlayerHealth.CONTACT_INTERVAL)
	_arena._apply_contact_damage()
	assert_eq(player.health.hp, max_hp - 4 * shambler.contact_damage)
	assert_true(player.take_bullet(15))
	assert_false(player.take_bullet(15), "safe from bullets right after one hit")
	_arena._stage = 3
	assert_eq(_arena._scaled_damage(10), roundi(10 * Arena.DAMAGE_BY_DEPTH[2]), "later stages hit harder")


func test_level_ups_heal_a_little() -> void:
	var player := _local_player()
	player.health.hp = 10
	_arena._on_gem_collected(TeamProgress.xp_to_next(1), 1)
	assert_eq(player.health.hp, 10 + roundi(player.health.max_hp * Arena.LEVEL_UP_HEAL_SHARE))
