class_name RunStats
extends RefCounted
## Numbers for the end-of-run screen. The host records them during the run and
## sends one message at the end (`encode()` / `decode()`); every peer shows them.

## Per-player counters. Sent as numbers: only add new ones at the end.
## HP_LOST counted hearts until v0.22.0.
enum Stat { KILLS, DAMAGE, BOSS_DAMAGE, HP_LOST, DOWNS, COINS_EARNED, XP_GATHERED, REVIVES }

## Row labels for the panel, same order as Stat.
const STAT_LABELS: Array[String] = ["Kills", "Damage", "Boss damage", "Damage taken", "Downed", "Coins earned", "XP gathered", "Revives"]

## Co-op awards: the player who leads in this stat gets the title.
const AWARDS: Dictionary[Stat, String] = {
	Stat.DAMAGE: "Most damage",
	Stat.KILLS: "Most kills",
	Stat.BOSS_DAMAGE: "Boss slayer",
	Stat.XP_GATHERED: "Gem hoarder",
	Stat.REVIVES: "Lifesaver",
}

## Stats where less is better (the star goes to the lowest).
const LOWER_IS_BETTER: Array[Stat] = [Stat.HP_LOST, Stat.DOWNS]

## peer id -> one int per Stat
var by_peer: Dictionary[int, PackedInt32Array] = {}
## Weapon breakdown: peer id -> DamageSource id -> [damage, kills, seconds owned].
var sources: Dictionary[int, Dictionary] = {}
## Seconds of actual play (level-up and shop pauses don't count).
var run_seconds: float = 0.0
var stage_reached: int = 1
var team_level: int = 1
var bosses_defeated: int = 0
var victory: bool = false
## What ended the run, e.g. "The Bone Warden" (empty when the horde did it).
var fell_to: String = ""


func add(peer_id: int, stat: Stat, amount: int) -> void:
	if not by_peer.has(peer_id):
		var values := PackedInt32Array()
		values.resize(Stat.size())
		by_peer[peer_id] = values
	# Packed arrays are values: change the stored one directly.
	by_peer[peer_id][stat] += amount


func set_stat(peer_id: int, stat: Stat, value: int) -> void:
	add(peer_id, stat, value - get_stat(peer_id, stat))


func get_stat(peer_id: int, stat: Stat) -> int:
	return by_peer[peer_id][stat] if by_peer.has(peer_id) else 0


func total(stat: Stat) -> int:
	var sum := 0
	for peer_id: int in by_peer:
		sum += by_peer[peer_id][stat]
	return sum


## The one player clearly ahead in this stat, or -1 (solo, tie, or all zero).
func leader(stat: Stat) -> int:
	if by_peer.size() < 2:
		return -1
	var best_id := -1
	var best := 0
	var tied := false
	for peer_id: int in by_peer:
		var value := by_peer[peer_id][stat]
		if value > best:
			best = value
			best_id = peer_id
			tied = false
		elif value == best and value > 0:
			tied = true
	return -1 if tied else best_id


## Co-op: the one player with the best value in this stat (highest, or lowest
## for LOWER_IS_BETTER), or -1 (solo, a tie, or nobody did anything).
func best(stat: Stat) -> int:
	if not LOWER_IS_BETTER.has(stat):
		return leader(stat)
	if by_peer.size() < 2:
		return -1
	var best_id := -1
	var best_value := 0
	var tied := false
	for peer_id: int in by_peer:
		var value := by_peer[peer_id][stat]
		if best_id == -1 or value < best_value:
			best_value = value
			best_id = peer_id
			tied = false
		elif value == best_value:
			tied = true
	return -1 if tied else best_id


func set_source(peer_id: int, source: int, damage: int, kills: int, seconds: int) -> void:
	if not sources.has(peer_id):
		sources[peer_id] = {}
	sources[peer_id][source] = [damage, kills, seconds]


## This player's weapons, most damage first: [source, damage, kills, seconds] each.
func sources_for(peer_id: int) -> Array[Array]:
	var result: Array[Array] = []
	var table: Dictionary = sources.get(peer_id, {})
	for source: int in table:
		var values: Array = table[source]
		result.append([source, values[0], values[1], values[2]])
	result.sort_custom(func(a: Array, b: Array) -> bool:
		return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
	return result


## Damage per second over the time a weapon was owned.
static func dps(damage: int, seconds: int) -> float:
	return float(damage) / maxf(float(seconds), 1.0)


## Award titles this player earned (co-op only).
func awards_for(peer_id: int) -> Array[String]:
	var result: Array[String] = []
	for stat: Stat in AWARDS:
		if leader(stat) == peer_id:
			result.append(AWARDS[stat])
	return result


## "4:05" or "1:02:03".
static func format_time(seconds: float) -> String:
	var whole := maxi(floori(seconds), 0)
	if whole >= 3600:
		return "%d:%02d:%02d" % [whole / 3600, (whole / 60) % 60, whole % 60]
	return "%d:%02d" % [whole / 60, whole % 60]


func encode() -> Dictionary:
	var ids := PackedInt32Array()
	var values := PackedInt32Array()
	for peer_id: int in by_peer:
		ids.append(peer_id)
		values.append_array(by_peer[peer_id])
	# Breakdown as flat numbers: peer, source, damage, kills, seconds.
	var source_values := PackedInt32Array()
	for peer_id: int in sources:
		for row: Array in sources_for(peer_id):
			source_values.append_array([peer_id, row[0], row[1], row[2], row[3]])
	return {
		"ids": ids, "values": values, "sources": source_values, "seconds": run_seconds, "stage": stage_reached,
		"level": team_level, "bosses": bosses_defeated, "victory": victory, "fell_to": fell_to,
	}


static func decode(data: Dictionary) -> RunStats:
	var stats := RunStats.new()
	var ids: PackedInt32Array = data.get("ids", PackedInt32Array())
	var values: PackedInt32Array = data.get("values", PackedInt32Array())
	var count := Stat.size()
	for i: int in ids.size():
		if values.size() >= (i + 1) * count:
			stats.by_peer[ids[i]] = values.slice(i * count, (i + 1) * count)
	var source_values: PackedInt32Array = data.get("sources", PackedInt32Array())
	for i: int in range(0, source_values.size() - 4, 5):
		stats.set_source(source_values[i], source_values[i + 1], source_values[i + 2], source_values[i + 3], source_values[i + 4])
	stats.run_seconds = data.get("seconds", 0.0)
	stats.stage_reached = data.get("stage", 1)
	stats.team_level = data.get("level", 1)
	stats.bosses_defeated = data.get("bosses", 0)
	stats.victory = data.get("victory", false)
	stats.fell_to = data.get("fell_to", "")
	return stats
