class_name ShopSession
extends RefCounted
## One shop break between stages (host only). Pure logic, no networking.
##
## - Each participant has their own relic offers and spends their own coins.
## - Each participant also picks 1 of 3 quests for the next stage (free; a
##   random one of their offers if they don't pick).
## - Nothing times out until someone presses Ready. The first Ready starts a
##   countdown; the shop closes when everyone is ready or time runs out.

const COUNTDOWN_SECONDS: float = 45.0

## peer id -> offered relic ids
var offers: Dictionary[int, Array] = {}
var ready: Dictionary[int, bool] = {}
## peer id -> rerolls used in this shop
var rerolls: Dictionary[int, int] = {}
## peer id -> offered quest ids, and the one they picked
var quest_offers: Dictionary[int, Array] = {}
var quest_choice: Dictionary[int, int] = {}
## Seconds left after the first Ready; negative = not started yet.
var countdown_left: float = -1.0


func start(offered: Dictionary[int, Array], offered_quests: Dictionary[int, Array] = {}) -> void:
	offers = offered
	quest_offers = offered_quests
	quest_choice.clear()
	ready.clear()
	rerolls.clear()
	countdown_left = -1.0


## Returns true if the pick was allowed (an offered quest, before Ready).
func choose_quest(peer_id: int, quest_id: int) -> bool:
	if ready.has(peer_id) or not quest_offers.has(peer_id) or not quest_offers[peer_id].has(quest_id):
		return false
	quest_choice[peer_id] = quest_id
	return true


## Everyone's quest for the next stage: their pick, or a random offer if they
## didn't pick one.
func final_quests(rng: RandomNumberGenerator) -> Dictionary[int, int]:
	var result: Dictionary[int, int] = {}
	for peer_id: int in quest_offers:
		if quest_choice.has(peer_id):
			result[peer_id] = quest_choice[peer_id]
		elif not quest_offers[peer_id].is_empty():
			result[peer_id] = quest_offers[peer_id][rng.randi() % quest_offers[peer_id].size()]
	return result


func is_participant(peer_id: int) -> bool:
	return offers.has(peer_id)


func can_buy(peer_id: int, relic_id: int, coins: int, owned: Array[int]) -> bool:
	if not offers.has(peer_id) or ready.has(peer_id):
		return false
	if not offers[peer_id].has(relic_id) or owned.has(relic_id):
		return false
	return coins >= Relics.get_relic(relic_id).price


func reroll_price(peer_id: int) -> int:
	return Relics.REROLL_PRICE + Relics.REROLL_STEP * rerolls.get(peer_id, 0)


func can_reroll(peer_id: int, coins: int) -> bool:
	return offers.has(peer_id) and not ready.has(peer_id) and coins >= reroll_price(peer_id)


## Returns true if this changed anything.
func mark_ready(peer_id: int) -> bool:
	if not offers.has(peer_id) or ready.has(peer_id):
		return false
	ready[peer_id] = true
	if countdown_left < 0.0:
		countdown_left = COUNTDOWN_SECONDS
	return true


func remove(peer_id: int) -> void:
	offers.erase(peer_id)
	ready.erase(peer_id)
	quest_offers.erase(peer_id)
	quest_choice.erase(peer_id)


func tick(delta: float) -> void:
	if countdown_left > 0.0:
		countdown_left = maxf(countdown_left - delta, 0.0)


func is_finished() -> bool:
	return ready.size() >= offers.size() or countdown_left == 0.0


func waiting_for() -> Array[int]:
	var waiting: Array[int] = []
	for peer_id: int in offers:
		if not ready.has(peer_id):
			waiting.append(peer_id)
	return waiting
