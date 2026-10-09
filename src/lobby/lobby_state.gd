class_name LobbyState
extends RefCounted
## Who's in the lobby, which character each picked, and who's ready.
## Pure data with the start rule; the Lobby node handles networking and UI.

## Peer ids in join order (the host first).
var order: Array[int] = []
var characters: Dictionary[int, int] = {}
var ready: Dictionary[int, bool] = {}


func add(peer_id: int, character: int) -> void:
	if order.has(peer_id):
		return
	order.append(peer_id)
	characters[peer_id] = character
	ready[peer_id] = false


func remove(peer_id: int) -> void:
	order.erase(peer_id)
	characters.erase(peer_id)
	ready.erase(peer_id)


func choose(peer_id: int, character: int) -> bool:
	if not order.has(peer_id) or not Characters.is_valid_id(character):
		return false
	characters[peer_id] = character
	return true


func set_ready(peer_id: int, is_ready: bool) -> void:
	if order.has(peer_id):
		ready[peer_id] = is_ready


## The host can start once every other player is ready (pressing Start counts
## as the host being ready).
func can_start(host_id: int) -> bool:
	for peer_id: int in order:
		if peer_id != host_id and not ready.get(peer_id, false):
			return false
	return not order.is_empty()


func not_ready(host_id: int) -> Array[int]:
	var waiting: Array[int] = []
	for peer_id: int in order:
		if peer_id != host_id and not ready.get(peer_id, false):
			waiting.append(peer_id)
	return waiting
