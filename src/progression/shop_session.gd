class_name ShopSession
extends RefCounted
## One shop break between stages (host only). Pure logic, no networking.
##
## - Each participant has their own relic offers and spends their own coins.
## - Nothing times out until someone presses Ready. The first Ready starts a
##   countdown; the shop closes when everyone is ready or time runs out.

const COUNTDOWN_SECONDS: float = 45.0

## peer id -> offered relic ids
var offers: Dictionary[int, Array] = {}
var ready: Dictionary[int, bool] = {}
## peer id -> rerolls used in this shop
var rerolls: Dictionary[int, int] = {}
## Seconds left after the first Ready; negative = not started yet.
var countdown_left: float = -1.0


func start(offered: Dictionary[int, Array]) -> void:
	offers = offered
	ready.clear()
	rerolls.clear()
	countdown_left = -1.0


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
