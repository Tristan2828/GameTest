class_name ArenaRewards
extends Node
## The arena's part that hands out map event and power-up rewards. MapEvents
## decides when a champion falls, a chest opens or a ritual finishes; this pays
## out on the host and shows it on every peer.
##
## A child node of the Arena (in arena.tscn), so its RPCs reach the same node on
## every peer. It uses the arena's managers and players directly.

## Coins from a champion and a caught thief, and the chest's coins when every
## weapon is maxed.
const CHAMPION_COINS: int = 10
const RUNNER_COINS: int = 14
const CHEST_COINS_WHEN_MAXED: int = 30
## A finished ritual heals everyone inside this share of their max HP.
const RITUAL_HEAL_SHARE: float = 0.25
## A finished ritual's XP: this share of the current level's cost. (0.6 in
## v0.17-0.22: less than 15 s of normal fighting earned, so not worth the stand.)
const RITUAL_XP_SHARE: float = 1.5
## Enemies called per ritual wave (+1 per extra player), and from how far.
const RITUAL_WAVE_SIZE: int = 2
const RITUAL_WAVE_DISTANCE: float = 200.0

## Host: seconds until another random power-up may drop.
var power_up_cooldown: float = 0.0

@onready var arena: Arena = get_parent() as Arena


# --- Power-ups -----------------------------------------------------------------

## Host, on a kill: maybe a random power-up (one at most every DROP_COOLDOWN).
func maybe_drop_power_up(at: Vector2) -> void:
	if power_up_cooldown <= 0.0 and arena._rng.randf() < PowerUps.DROP_CHANCE:
		power_up_cooldown = PowerUps.DROP_COOLDOWN
		_drop_power_up(at, PowerUps.pick_kind(arena._rng.randf()))


## Host: put a power-up on the ground (Kind as its value).
func _drop_power_up(at: Vector2, kind: int) -> void:
	var inner := Arena.BOUNDS.grow(-12.0)
	arena._power_ups.spawn_host(at.clamp(inner.position, inner.end), kind)


## Host: someone grabbed a power-up. Apply it, then show it on every screen.
func on_power_up_collected(kind: int, collector_peer_id: int) -> void:
	var player := arena._player_by_id(collector_peer_id)
	if player == null or not PowerUps.is_valid_kind(kind):
		return
	arena._quests.count(collector_peer_id, Quests.Id.SCAVENGER)
	arena._balance.count(PowerUps.TITLES[kind])
	arena._run_stats.add(collector_peer_id, RunStats.Stat.POWER_UPS, 1)
	var at := player.state.position
	match kind:
		PowerUps.Kind.HEART:
			player.health.heal_share(PowerUps.HEART_HEAL_SHARE)
		PowerUps.Kind.HOLY_BOMB:
			var damage := roundi(PowerUps.BOMB_DAMAGE * Arena.hp_factor(false, arena._run_depth()) * arena._config.enemy_health)
			arena._enemies.smite(at, PowerUps.BOMB_RADIUS, damage, collector_peer_id, DamageSource.HOLY_BOMB)
		PowerUps.Kind.FROST_HOURGLASS:
			arena._enemies.freeze_all(PowerUps.FROST_SECONDS)
	_show_power_up(kind, collector_peer_id, at)
	for peer_id: int in arena._ready_peers:
		_receive_power_up.rpc_id(peer_id, kind, collector_peer_id, at)


## Everyone: a power-up went off (effects; Soul Magnet and frozen bullets run on every peer).
func _show_power_up(kind: int, collector_peer_id: int, at: Vector2) -> void:
	var player := arena._player_by_id(collector_peer_id)
	var who := player.display_name() if player != null else "Someone"
	if player != null and player.is_local():
		who = "You"
	match kind:
		PowerUps.Kind.HEART:
			arena._effects.burst(at, Arena.HURT_COLOR, 12, 60.0, 0.5, 1.5)
		PowerUps.Kind.SOUL_MAGNET:
			arena._gems.attract_all(collector_peer_id)
			arena._effects.burst(at, Color(0.5, 0.75, 1.0), 16, 90.0, 0.5, 1.5)
		PowerUps.Kind.HOLY_BOMB:
			arena._abilities.detonate_blast(at, PowerUps.BOMB_RADIUS)
			arena._effects.burst(at, Color(1.0, 0.9, 0.5), 30, 200.0, 0.6, 2.0)
		PowerUps.Kind.FROST_HOURGLASS:
			arena._enemy_bullets.freeze_all(PowerUps.FROST_SECONDS)
			arena._effects.burst(at, PowerUps.FROST_COLOR, 24, 140.0, 0.6, 1.5)
			Sfx.play(&"hex", -4.0, 1.5)
	arena._hud.toast("%s grabbed %s!" % [who, PowerUps.TITLES[kind]], Color(1.0, 0.9, 0.6))


# --- Map events ----------------------------------------------------------------

## Host: a champion or thief for an event. Champions get tougher with more players, like bosses.
func spawn_event_enemy(type_id: int, at: Vector2) -> Enemy:
	var type := EnemyTypes.get_type(type_id)
	var players := maxi(arena._player_nodes().size(), 1)
	var hit_points := roundi(arena._scaled_hp(type_id) * (1.0 + type.hp_per_extra_player * (players - 1)))
	return arena._enemies.spawn(type_id, at, hit_points)


## Host: a champion died: a pile of coins and a power-up next to its chest.
func on_champion_slain(at: Vector2, _champion_type: int) -> void:
	arena._balance.count("champion")
	for player: Player in arena._player_nodes():
		arena._quests.count(player.peer_id, Quests.Id.CHAMPION_HUNTER)
	_scatter_coins(at, CHAMPION_COINS, 3, 26.0)
	_drop_power_up(at + Vector2(0, 18), PowerUps.pick_kind(arena._rng.randf()))


## Host: the first player to touch a champion's chest gets an evolution if one
## is ready, else a weapon (new, or a level of one they carry); with nothing
## left to give, coins instead.
func on_chest_opened(peer_id: int, at: Vector2) -> void:
	var player := arena._player_by_id(peer_id)
	if player == null:
		return
	arena._run_stats.add(peer_id, RunStats.Stat.CHESTS, 1)
	_show_chest_opened(at)
	for target: int in arena._ready_peers:
		_receive_chest_opened.rpc_id(target, at)
	var card := Cards.chest_card(arena._rng, player)
	if card < 0:
		player.coins += CHEST_COINS_WHEN_MAXED
		arena._run_stats.add(peer_id, RunStats.Stat.COINS_EARNED, CHEST_COINS_WHEN_MAXED)
		arena._events.announce("%s opened the chest: %d coins!" % [player.display_name(), CHEST_COINS_WHEN_MAXED])
		return
	if Cards.is_evolution(card):
		_grant_evolution(player, card)
		return
	var level := Cards.levels(card, player).x + 1
	arena._level_up.host_grant(peer_id, card, arena._ready_peer_list())
	arena._events.announce("%s opened the chest: %s%s!" % [player.display_name(), Cards.title(card, player.stats),
		"" if level <= 1 else " Lv %d" % level])


## Host: an altar had nothing left for this player; it paid coins instead.
func on_altar_coins_given(peer_id: int, amount: int) -> void:
	var player := arena._player_by_id(peer_id)
	if player == null:
		return
	arena._run_stats.add(peer_id, RunStats.Stat.COINS_EARNED, amount)
	arena._events.announce("%s took the altar: nothing left to learn, %d coins!" % [player.display_name(), amount])


## Host: the boss fell; every player's ready evolutions happen now.
func evolve_ready_weapons() -> void:
	for player: Player in arena._player_nodes():
		for card: int in Cards.ready_evolutions(player):
			_grant_evolution(player, card)


## Host: evolve a weapon (from a chest or a boss) and tell the team.
func _grant_evolution(player: Player, card: int) -> void:
	var before := Cards.title(Cards.MAIN_LEVEL if card == Cards.MAIN_EVOLUTION else Cards.weapon(
		AutoWeapons.get_weapon(Cards.weapon_id(card)).evolves_from), player.stats)
	arena._level_up.host_grant(player.peer_id, card, arena._ready_peer_list())
	arena._run_stats.add(player.peer_id, RunStats.Stat.EVOLUTIONS, 1)
	arena._events.announce("%s's %s evolved into %s!" % [player.display_name(), before, Cards.title(card, player.stats)])


## Host: everyone in the circle heals, and a ring of XP gems worth most of a level appears.
func on_ritual_completed(at: Vector2, inside: Array[int]) -> void:
	arena._balance.count("ritual")
	for peer_id: int in inside:
		arena._quests.count(peer_id, Quests.Id.RITUALIST)
		arena._run_stats.add(peer_id, RunStats.Stat.RITUALS, 1)
	for peer_id: int in inside:
		var player := arena._player_by_id(peer_id)
		if player != null:
			player.health.heal_share(RITUAL_HEAL_SHARE)
	var team := arena._team
	var total := roundi(TeamProgress.xp_to_next(team.level, team.player_count, team.xp_rate) * RITUAL_XP_SHARE)
	var gems := clampi(total / 5, 6, 24)
	for i: int in gems:
		var value := maxi(total / gems + (1 if i < total % gems else 0), 1)
		var spot := at + Vector2.from_angle(TAU * i / gems) * arena._rng.randf_range(14.0, 34.0)
		if not arena._gems.spawn_host(spot, value):
			arena._on_gem_collected(value, inside[0] if not inside.is_empty() else 1)
	_show_ritual_done(at)
	for target: int in arena._ready_peers:
		_receive_ritual_done.rpc_id(target, at)


## Host: the thief bursts into a shower of coins.
func on_runner_caught(at: Vector2) -> void:
	arena._balance.count("thief caught")
	for player: Player in arena._player_nodes():
		arena._quests.count(player.peer_id, Quests.Id.THIEF_CATCHER)
	_scatter_coins(at, RUNNER_COINS, 2, 30.0)


## Host: a ritual calls a few of this stage's enemies from around the circle.
func on_ritual_wave(at: Vector2) -> void:
	var count := RITUAL_WAVE_SIZE + arena._player_nodes().size() - 1
	var inner := Arena.BOUNDS.grow(-16.0)
	for i: int in count:
		var type_id := _random_stage_enemy()
		var spot := (at + Vector2.from_angle(arena._rng.randf() * TAU) * RITUAL_WAVE_DISTANCE).clamp(inner.position, inner.end)
		arena._enemies.spawn(type_id, spot, arena._scaled_hp(type_id))


## Everyone: a line about an event (toast + chime).
func on_event_announced(text: String) -> void:
	arena._hud.toast(text, Color(1.0, 0.85, 0.5))
	Sfx.play(&"event", -8.0)


## A regular enemy type this stage is already sending (by its spawn weights).
func _random_stage_enemy() -> int:
	var stage := Stages.get_stage(arena._stage)
	var entries: Array[SpawnEntry] = []
	var total := 0.0
	for entry: SpawnEntry in stage.spawns:
		if entry.unlock_time <= arena._elapsed:
			entries.append(entry)
			total += entry.weight
	if entries.is_empty():
		return stage.pack_type
	var roll := arena._rng.randf() * total
	for entry: SpawnEntry in entries:
		roll -= entry.weight
		if roll <= 0.0:
			return entry.enemy_type
	return entries[-1].enemy_type


func _scatter_coins(at: Vector2, count: int, value: int, spread: float) -> void:
	var inner := Arena.BOUNDS.grow(-8.0)
	for i: int in count:
		var spot := (at + Vector2.from_angle(arena._rng.randf() * TAU) * arena._rng.randf_range(4.0, spread)).clamp(inner.position, inner.end)
		arena._coins.spawn_host(spot, value)


## Everyone: a chest bursts open.
func _show_chest_opened(at: Vector2) -> void:
	arena._effects.burst(at, Color(1.0, 0.85, 0.4), 24, 110.0, 0.6, 1.5)
	if arena._near_local_player(at):
		Sfx.play(&"chest", -2.0)


## Everyone: a ritual finished.
func _show_ritual_done(at: Vector2) -> void:
	arena._effects.burst(at, MapEvents.RITUAL_COLOR, 30, 120.0, 0.7, 2.0)
	var ring := BombBlast.new()
	ring.radius = MapEvents.RITUAL_RADIUS * 1.5
	ring.color = MapEvents.RITUAL_FILL_COLOR
	ring.position = at
	arena.add_child(ring)
	if arena._near_local_player(at):
		Sfx.play(&"revive", -3.0)


@rpc("authority", "call_remote", "reliable")
func _receive_power_up(kind: int, collector_peer_id: int, at: Vector2) -> void:
	if PowerUps.is_valid_kind(kind):
		_show_power_up(kind, collector_peer_id, at)


@rpc("authority", "call_remote", "reliable")
func _receive_chest_opened(at: Vector2) -> void:
	_show_chest_opened(at)


@rpc("authority", "call_remote", "reliable")
func _receive_ritual_done(at: Vector2) -> void:
	_show_ritual_done(at)
