class_name ArenaQuests
extends Node
## The arena's part that runs this stage's quests (picked in the shop): the host
## counts progress and pays out; every peer shows the fanfare.
##
## A child node of the Arena (in arena.tscn), so its RPCs reach the same node on
## every peer. It uses the arena's managers and players directly.

## A relic quest pays this instead when the player already owns every relic.
const QUEST_COINS_WHEN_NO_RELIC: int = 40

## Host: everyone's quest for this stage and its progress.
var tracker: QuestTracker = QuestTracker.new()
## Host: Arsenal counts auto weapon damage from the stage start (peer -> damage then).
var _damage_base: Dictionary[int, int] = {}
## Host: Untouchable restarts when hp_lost changes (peer -> hp_lost last tick).
var _hp_seen: Dictionary[int, int] = {}

@onready var arena: Arena = get_parent() as Arena


## Host: a new stage's quests, picked in the shop.
func start(chosen: Dictionary[int, int]) -> void:
	tracker.clear()
	_damage_base.clear()
	_hp_seen.clear()
	for player: Player in arena._player_nodes():
		var quest_id: int = chosen.get(player.peer_id, -1)
		player.quest_id = quest_id
		player.quest_progress = 0
		if quest_id < 0:
			continue
		tracker.assign(player.peer_id, quest_id)
		_damage_base[player.peer_id] = _auto_weapon_damage(player.peer_id)
		_hp_seen[player.peer_id] = player.hp_lost
		print("Player %d quest: %s" % [player.peer_id, Quests.TITLES[quest_id]])


## Host: the stage ended; nobody has a quest until the next shop.
func clear() -> void:
	tracker.clear()
	for player: Player in arena._player_nodes():
		player.quest_id = -1


## Host: a player left.
func remove(peer_id: int) -> void:
	tracker.remove(peer_id)


## Host: progress on a quest; pays out the moment it's done.
func count(peer_id: int, quest_id: int, amount: float = 1.0) -> void:
	if tracker.count(peer_id, quest_id, amount):
		_pay(peer_id)


## Host, every tick: quests that are about time or totals (Untouchable, Arsenal),
## and the progress every player sees.
func tick(delta: float) -> void:
	for player: Player in arena._player_nodes():
		var peer_id := player.peer_id
		if tracker.is_on(peer_id, Quests.Id.UNTOUCHABLE):
			var hit: bool = player.hp_lost != _hp_seen.get(peer_id, player.hp_lost)
			_hp_seen[peer_id] = player.hp_lost
			if hit or player.is_downed():
				tracker.set_progress(peer_id, Quests.Id.UNTOUCHABLE, 0.0)
			else:
				count(peer_id, Quests.Id.UNTOUCHABLE, delta)
		if tracker.is_on(peer_id, Quests.Id.ARSENAL):
			var dealt: int = _auto_weapon_damage(peer_id) - _damage_base.get(peer_id, 0)
			if tracker.set_progress(peer_id, Quests.Id.ARSENAL, dealt):
				_pay(peer_id)
		player.quest_progress = tracker.shown_progress(peer_id)


## "Quest: Slayer 120/250" for the HUD ("" without a quest).
func text_for(player: Player) -> String:
	if player.quest_id < 0 or arena._is_between_stages():
		return ""
	var target := Quests.TARGETS[player.quest_id]
	if player.quest_progress >= target:
		return "Quest done: %s" % Quests.TITLES[player.quest_id]
	if target <= 1:
		return "Quest: %s (%s)" % [Quests.TITLES[player.quest_id], Quests.description(player.quest_id)]
	return "Quest: %s %d/%d" % [Quests.TITLES[player.quest_id], player.quest_progress, target]


## Host: all damage this player has dealt with auto weapons this run.
func _auto_weapon_damage(peer_id: int) -> int:
	var total := 0
	var by_source: Dictionary = arena._enemies.damage_by_source.get(peer_id, {})
	for source: int in by_source:
		if DamageSource.weapon_id(source) >= 0:
			total += int(by_source[source])
	return total


## Host: a quest is done. Coins, or a relic the player doesn't own yet (coins
## if they own them all).
func _pay(peer_id: int) -> void:
	var player := arena._player_by_id(peer_id)
	var quest_id: int = tracker.quest_of.get(peer_id, -1)
	if player == null or quest_id < 0:
		return
	player.quest_progress = Quests.TARGETS[quest_id]
	var reward := "%d coins" % Quests.REWARDS[quest_id]
	var coins := Quests.REWARDS[quest_id]
	if coins == Quests.RELIC_REWARD:
		var relics := Relics.roll_offers(arena._rng, player.relic_ids, arena._player_nodes().size() > 1, player.stats)
		if relics.is_empty():
			coins = QUEST_COINS_WHEN_NO_RELIC
			reward = "%d coins" % coins
		else:
			arena._shop.host_grant_relic(peer_id, relics[0], arena._ready_peer_list())
			reward = Relics.get_relic(relics[0]).title
	if coins > 0:
		player.coins += coins
		arena._run_stats.add(peer_id, RunStats.Stat.COINS_EARNED, coins)
	var text := "%s completed a quest: %s! (%s)" % [player.display_name(), Quests.TITLES[quest_id], reward]
	arena._balance.count("quest")
	arena._run_stats.add(peer_id, RunStats.Stat.QUESTS, 1)
	print(text)
	_show_done(peer_id, text)
	for target: int in arena._ready_peers:
		_receive_done.rpc_id(target, peer_id, text)


## Everyone: a quest was finished (a fanfare for the player who did it).
func _show_done(peer_id: int, text: String) -> void:
	arena._hud.toast(text, Hud.QUEST_DONE_COLOR)
	var player := arena._player_by_id(peer_id)
	if player != null and player.is_local():
		Sfx.play(&"quest", -3.0)
		arena._effects.burst(player.world_position(), Hud.QUEST_DONE_COLOR, 20, 90.0, 0.6, 1.5)


@rpc("authority", "call_remote", "reliable")
func _receive_done(peer_id: int, text: String) -> void:
	_show_done(peer_id, text)
