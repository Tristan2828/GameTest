class_name BalanceLog
extends Node
## Host: the numbers of each stage, for tuning difficulty. When a stage ends it
## prints the `[balance]`, `[balance-detail]` and `[balance-picks]` lines (see
## CLAUDE.md "Balance check") and adds the stage's row to the run summary's
## Stages page.
##
## A child node of the Arena (in arena.tscn). It reads the arena's managers and
## players directly.

## Numbers at the start of the stage (kills, damage, hp lost, downs).
var _start: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## Stage time the boss arrived (-1 = not yet).
var _boss_at: float = -1.0
## The most enemies alive at once this stage.
var _peak_alive: int = 0
## Events, pickups and quests this stage (name -> count), for `[balance-detail]`.
var _counts: Dictionary[String, int] = {}
var _coins_start: int = 0
var _source_start: Dictionary[int, int] = {}

@onready var arena: Arena = get_parent() as Arena


## Something happened this stage ("champion", "ritual", "quest", a power-up title...).
func count(what: String) -> void:
	_counts[what] = _counts.get(what, 0) + 1


## The boss arrived now.
func note_boss() -> void:
	_boss_at = arena._elapsed


## Called while spawning: remembers the busiest moment.
func note_alive(alive: int) -> void:
	_peak_alive = maxi(_peak_alive, alive)


## One line per stage for tuning difficulty: how long the waves and the boss
## took, how hurt the team got, and how hard it hit. Compare stages with it.
func end_stage(phase: Arena.Phase) -> void:
	var damage := 0
	for peer_id: int in arena._enemies.damage_by_peer:
		damage += arena._enemies.damage_by_peer[peer_id]
	var hp_lost := 0
	var downs := 0
	var max_hp := 0
	for player: Player in arena._player_nodes():
		hp_lost += player.hp_lost
		downs += player.times_downed
		max_hp += player.health.max_hp
	var run_stats := arena._run_stats
	var now := PackedInt32Array([run_stats.total(RunStats.Stat.KILLS), damage, hp_lost, downs])
	var elapsed := arena._elapsed
	var boss_seconds := elapsed - _boss_at if _boss_at >= 0.0 else 0.0
	print("[balance] stage %d %s: time %.0fs (boss fight %.0fs)  team level %d  kills %d  dps %.0f  hp lost %d (team max hp %d)  downs %d  peak enemies %d  players %d" % [
		arena._run_depth(), Arena.Phase.keys()[phase], elapsed, boss_seconds, arena._team.level, now[0] - _start[0],
		(now[1] - _start[1]) / maxf(elapsed, 1.0), now[2] - _start[2], max_hp, now[3] - _start[3],
		_peak_alive, arena._player_nodes().size()])
	# The same numbers for the run summary's Stages page.
	run_stats.add_stage_row({
		RunStats.StageField.MAP: arena._stage,
		RunStats.StageField.SECONDS: roundi(elapsed),
		RunStats.StageField.BOSS_SECONDS: roundi(boss_seconds) if _boss_at >= 0.0 else -1,
		RunStats.StageField.KILLS: now[0] - _start[0],
		RunStats.StageField.HP_LOST: now[2] - _start[2],
		RunStats.StageField.DOWNS: now[3] - _start[3],
		RunStats.StageField.LEVEL: arena._team.level,
		RunStats.StageField.EVENTS: _counts.get("champion", 0) + _counts.get("ritual", 0)
			+ _counts.get("thief caught", 0),
		RunStats.StageField.CLEARED: 1 if phase == Arena.Phase.STAGE_CLEAR else 0,
		RunStats.StageField.PEAK_ENEMIES: _peak_alive,
	})
	_start = now
	_boss_at = -1.0
	_peak_alive = 0
	_print_detail()


## Second balance line: coins, pickups, events and quests, and each damage
## source's share this stage. Then each player's picks so far.
func _print_detail() -> void:
	var coins := arena._run_stats.total(RunStats.Stat.COINS_EARNED)
	var by_source: Dictionary[int, int] = {}
	for peer_id: int in arena._enemies.damage_by_source:
		var sources: Dictionary = arena._enemies.damage_by_source[peer_id]
		for source: int in sources:
			by_source[source] = by_source.get(source, 0) + int(sources[source])
	var total := 0
	for source: int in by_source:
		total += by_source[source] - _source_start.get(source, 0)
	var players := arena._player_nodes()
	var shares: PackedStringArray = []
	for source: int in by_source:
		var dealt: int = by_source[source] - _source_start.get(source, 0)
		if dealt > 0:
			var stats := players[0].stats if not players.is_empty() else null
			shares.append("%s %d%%" % [DamageSource.title(source, stats), roundi(100.0 * dealt / maxf(total, 1.0))])
	var counts: PackedStringArray = []
	for what: String in _counts:
		counts.append("%s %d" % [what, _counts[what]])
	# Coins left on the ground and the boss bounty are paid after this line (next stage's count).
	print("[balance-detail] stage %d: coins picked up %d (+%d on the ground)  %s  damage: %s" % [arena._run_depth(),
		coins - _coins_start, arena._coins.total_value(), "  ".join(counts), ", ".join(shares)])
	for player: Player in players:
		var picks: PackedStringArray = []
		for id: int in player.upgrade_ids:
			picks.append(Upgrades.get_upgrade(id).title)
		var weapons: PackedStringArray = []
		for weapon_id: int in player.weapon_levels:
			weapons.append("%s %d" % [AutoWeapons.get_weapon(weapon_id).title, player.weapon_levels[weapon_id]])
		var relics: PackedStringArray = []
		for relic_id: int in player.relic_ids:
			relics.append(Relics.get_relic(relic_id).title)
		print("[balance-picks] %s: coins %d  main Lv %d%s  weapons [%s]  relics [%s]  upgrades [%s]" % [
			player.display_name(), player.coins, player.main_level, " (evolved)" if player.main_evolved else "",
			", ".join(weapons), ", ".join(relics), ", ".join(picks)])
	_counts.clear()
	_coins_start = coins
	_source_start = by_source
