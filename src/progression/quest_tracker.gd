class_name QuestTracker
extends RefCounted
## Host: every player's quest for this stage and how far along it is. Pure
## logic (no nodes or networking), so it's easy to test. The arena reports what
## happens (kills, coins, rituals...) and pays out when count() says a quest
## was just finished.

## peer id -> Quests id
var quest_of: Dictionary[int, int] = {}
## peer id -> progress (seconds for Untouchable, damage for Arsenal...)
var progress: Dictionary[int, float] = {}
## peer id -> finished (and paid) this stage
var finished: Dictionary[int, bool] = {}


func assign(peer_id: int, quest_id: int) -> void:
	quest_of[peer_id] = quest_id
	progress[peer_id] = 0.0
	finished.erase(peer_id)


func clear() -> void:
	quest_of.clear()
	progress.clear()
	finished.clear()


func remove(peer_id: int) -> void:
	quest_of.erase(peer_id)
	progress.erase(peer_id)
	finished.erase(peer_id)


## True if this player is working on this quest (and hasn't finished it).
func is_on(peer_id: int, quest_id: int) -> bool:
	return quest_of.get(peer_id, -1) == quest_id and not finished.has(peer_id)


## Adds to the player's progress if they're on this quest. Returns true the
## moment it's finished (exactly once).
func count(peer_id: int, quest_id: int, amount: float = 1.0) -> bool:
	if not is_on(peer_id, quest_id):
		return false
	return set_progress(peer_id, quest_id, progress.get(peer_id, 0.0) + amount)


## Sets the player's progress if they're on this quest. Returns true the moment it's finished.
func set_progress(peer_id: int, quest_id: int, value: float) -> bool:
	if not is_on(peer_id, quest_id):
		return false
	progress[peer_id] = value
	if value >= Quests.TARGETS[quest_id]:
		finished[peer_id] = true
		return true
	return false


## Progress as a whole number for the HUD (the target once finished).
func shown_progress(peer_id: int) -> int:
	var quest_id: int = quest_of.get(peer_id, -1)
	if quest_id < 0:
		return 0
	if finished.has(peer_id):
		return Quests.TARGETS[quest_id]
	return mini(floori(progress.get(peer_id, 0.0)), Quests.TARGETS[quest_id])
