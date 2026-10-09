class_name LevelUpSession
extends RefCounted
## One level-up pause (host only). Pure logic, no networking, so it's testable.
##
## Rules (see DESIGN.md, Co-op rules):
## - Each participant gets their own choices and picks one.
## - Nothing times out until someone picks. The first pick starts a countdown.
## - Ends when everyone has picked, or when the countdown runs out. Anyone who
##   hasn't picked by then gets a random one of their choices.

const COUNTDOWN_SECONDS: float = 30.0

## peer id -> offered upgrade ids
var choices: Dictionary[int, Array] = {}
## peer id -> chosen upgrade id
var picks: Dictionary[int, int] = {}
## Seconds left after the first pick; negative = not started yet.
var countdown_left: float = -1.0


func start(offered: Dictionary[int, Array]) -> void:
	choices = offered
	picks.clear()
	countdown_left = -1.0


## Returns true if the pick was accepted.
func pick(peer_id: int, upgrade_id: int) -> bool:
	if not choices.has(peer_id) or picks.has(peer_id):
		return false
	if not choices[peer_id].has(upgrade_id):
		return false
	picks[peer_id] = upgrade_id
	if countdown_left < 0.0:
		countdown_left = COUNTDOWN_SECONDS
	return true


## A player left mid-pause: stop waiting for them.
func remove(peer_id: int) -> void:
	choices.erase(peer_id)
	picks.erase(peer_id)


func tick(delta: float) -> void:
	if countdown_left > 0.0:
		countdown_left = maxf(countdown_left - delta, 0.0)


func is_finished() -> bool:
	return picks.size() >= choices.size() or countdown_left == 0.0


## Peers who still need to pick.
func waiting_for() -> Array[int]:
	var waiting: Array[int] = []
	for peer_id: int in choices:
		if not picks.has(peer_id):
			waiting.append(peer_id)
	return waiting


## Final picks for everyone, filling in random choices for anyone who didn't pick.
func final_picks(rng: RandomNumberGenerator) -> Dictionary[int, int]:
	var result: Dictionary[int, int] = picks.duplicate()
	for peer_id: int in waiting_for():
		var offered: Array = choices[peer_id]
		if not offered.is_empty():
			result[peer_id] = offered[rng.randi() % offered.size()]
	return result
