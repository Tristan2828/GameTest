class_name ShopController
extends Node
## Runs the shop break across the network.
##
## Host: rolls each player's relic and quest offers, validates buys/rerolls
## against the player's coins, and announces every purchase so all peers apply
## the relic. Quest picks are kept until the next stage starts.
## Everyone: shows this machine's shop panel and sends the local requests.

## Every peer: this player bought this relic (the arena applies it).
signal relic_bought(peer_id: int, relic_id: int)

const AUTOPILOT_DELAY: float = 1.0

## Peers still shopping (host: from the session; clients: from snapshots).
var waiting_ids: Array[int] = []
var countdown_left: float = -1.0

var _session: ShopSession = ShopSession.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _panel: ShopPanel = null
## Host helpers from the arena: peer id -> Player, and the loaded peers.
var _find_player: Callable
var _get_ready_peers: Callable
var _my_offers: Array[int] = []
var _my_quest_offers: Array[int] = []
var _my_quest: int = -1
var _my_reroll_price: int = Relics.REROLL_PRICE
var _open: bool = false
var _ready_sent: bool = false


func _ready() -> void:
	_rng.randomize()


func bind(panel: ShopPanel, find_player: Callable, get_ready_peers: Callable) -> void:
	_panel = panel
	_find_player = find_player
	_get_ready_peers = get_ready_peers
	_panel.buy_pressed.connect(_buy_locally)
	_panel.reroll_pressed.connect(_reroll_locally)
	_panel.ready_pressed.connect(_ready_locally)
	_panel.quest_pressed.connect(_choose_quest_locally)


func is_open_locally() -> bool:
	return _open


# --- Host ----------------------------------------------------------------------

func host_start(players: Array[Player], ready_peers: Array[int]) -> void:
	var offered: Dictionary[int, Array] = {}
	var quests: Dictionary[int, Array] = {}
	var co_op := not multiplayer.get_peers().is_empty()
	for player: Player in players:
		if player.peer_id == multiplayer.get_unique_id() or ready_peers.has(player.peer_id):
			offered[player.peer_id] = Relics.roll_offers(_rng, player.relic_ids, co_op, player.stats)
			quests[player.peer_id] = Quests.roll_offers(_rng, co_op)
	_session.start(offered, quests)
	_refresh_host_status()
	for peer_id: int in offered:
		_send_offers(peer_id)


## Returns true when the shop is over.
func host_tick(delta: float) -> bool:
	_session.tick(delta)
	_refresh_host_status()
	if _session.is_finished():
		close_local()
		return true
	return false


func host_remove_player(peer_id: int) -> void:
	_session.remove(peer_id)


## Host, when the next stage starts: everyone's quest (picked, or random).
func host_take_quests() -> Dictionary[int, int]:
	return _session.final_quests(_rng)


## Host: give a player a relic for free (quest reward), here and on every client.
func host_grant_relic(peer_id: int, relic_id: int, ready_peers: Array[int]) -> void:
	relic_bought.emit(peer_id, relic_id)
	for target: int in ready_peers:
		_receive_relic_bought.rpc_id(target, peer_id, relic_id)


func _host_choose_quest(peer_id: int, quest_id: int) -> void:
	if not _session.choose_quest(peer_id, quest_id):
		return
	if peer_id == multiplayer.get_unique_id():
		_show_quest_choice(quest_id)
	else:
		_receive_quest_choice.rpc_id(peer_id, quest_id)


## Host: tell a late joiner every relic each player already owns.
func host_send_history(to_peer: int, players: Array[Player]) -> void:
	for player: Player in players:
		if not player.relic_ids.is_empty():
			_receive_relic_history.rpc_id(to_peer, player.peer_id, PackedInt32Array(player.relic_ids))


func _host_buy(peer_id: int, relic_id: int, ready_peers: Array[int]) -> void:
	var player: Player = _find_player.call(peer_id)
	if player == null or not _session.can_buy(peer_id, relic_id, player.coins, player.relic_ids):
		return
	player.coins -= Relics.get_relic(relic_id).price
	relic_bought.emit(peer_id, relic_id)
	for target: int in ready_peers:
		_receive_relic_bought.rpc_id(target, peer_id, relic_id)


func _host_reroll(peer_id: int) -> void:
	var player: Player = _find_player.call(peer_id)
	if player == null or not _session.can_reroll(peer_id, player.coins):
		return
	player.coins -= _session.reroll_price(peer_id)
	_session.rerolls[peer_id] = _session.rerolls.get(peer_id, 0) + 1
	_session.offers[peer_id] = Relics.roll_offers(_rng, player.relic_ids, not multiplayer.get_peers().is_empty(),
		player.stats)
	_send_offers(peer_id)


func _host_ready(peer_id: int) -> void:
	_session.mark_ready(peer_id)
	_refresh_host_status()


func _send_offers(peer_id: int) -> void:
	var offer: Array[int] = []
	offer.assign(_session.offers[peer_id])
	var quests: Array[int] = []
	quests.assign(_session.quest_offers.get(peer_id, []))
	var price := _session.reroll_price(peer_id)
	if peer_id == multiplayer.get_unique_id():
		_show_offers(offer, price, quests)
	else:
		_receive_offers.rpc_id(peer_id, price, PackedInt32Array(offer), PackedInt32Array(quests))


func _refresh_host_status() -> void:
	waiting_ids = _session.waiting_for()
	countdown_left = _session.countdown_left


# --- Everyone ------------------------------------------------------------------

func apply_status(waiting: PackedInt32Array, countdown: float) -> void:
	waiting_ids.assign(waiting)
	countdown_left = countdown


func close_local() -> void:
	_open = false
	_my_offers.clear()
	_my_quest_offers.clear()
	_my_quest = -1
	_ready_sent = false
	if _panel != null:
		_panel.hide()


## Called every frame by the arena while the shop is open.
func refresh_panel(local_player: Player, name_of: Callable) -> void:
	if not _open or _panel == null or local_player == null:
		return
	var parts := PackedStringArray()
	if _ready_sent and not waiting_ids.is_empty():
		var names := PackedStringArray()
		for peer_id: int in waiting_ids:
			names.append(name_of.call(peer_id))
		parts.append("Waiting for %s" % ", ".join(names))
	if countdown_left >= 0.0:
		parts.append("%ds left" % ceili(countdown_left))
	_panel.refresh(local_player.coins, local_player.relic_ids, _ready_sent, "   ".join(parts), _my_reroll_price, _my_quest)


func _show_offers(offers: Array[int], reroll_price: int, quests: Array[int]) -> void:
	var first_time := not _open
	_my_offers = offers
	_my_quest_offers = quests
	_my_reroll_price = reroll_price
	_open = true
	if _panel != null:
		_panel.open(offers, quests, first_time)
	if LaunchOptions.autopilot and first_time:
		get_tree().create_timer(AUTOPILOT_DELAY).timeout.connect(_autopilot_shop)


func _show_quest_choice(quest_id: int) -> void:
	_my_quest = quest_id


func _autopilot_shop() -> void:
	if not _open or _ready_sent:
		return
	if not _my_quest_offers.is_empty():
		_choose_quest_locally(_my_quest_offers[0])
	for relic_id: int in _my_offers:
		_buy_locally(relic_id)
	get_tree().create_timer(0.5).timeout.connect(_ready_locally)


func _buy_locally(relic_id: int) -> void:
	if multiplayer.is_server():
		_host_buy(multiplayer.get_unique_id(), relic_id, _ready_peers_for_host())
	else:
		_request_buy.rpc_id(1, relic_id)


func _choose_quest_locally(quest_id: int) -> void:
	if not _open or _ready_sent:
		return
	if multiplayer.is_server():
		_host_choose_quest(multiplayer.get_unique_id(), quest_id)
	else:
		_request_quest.rpc_id(1, quest_id)


func _reroll_locally() -> void:
	if multiplayer.is_server():
		_host_reroll(multiplayer.get_unique_id())
	else:
		_request_reroll.rpc_id(1)


func _ready_locally() -> void:
	if not _open or _ready_sent:
		return
	_ready_sent = true
	if multiplayer.is_server():
		_host_ready(multiplayer.get_unique_id())
	else:
		_request_ready.rpc_id(1)


func _ready_peers_for_host() -> Array[int]:
	return _get_ready_peers.call()


# --- Network messages ------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _receive_offers(reroll_price: int, ids: PackedInt32Array, quest_ids: PackedInt32Array) -> void:
	var offers: Array[int] = []
	for id: int in ids:
		if Relics.is_valid_id(id):
			offers.append(id)
	var quests: Array[int] = []
	for id: int in quest_ids:
		if Quests.is_valid_id(id):
			quests.append(id)
	_show_offers(offers, reroll_price, quests)


@rpc("any_peer", "call_remote", "reliable")
func _request_quest(quest_id: int) -> void:
	if multiplayer.is_server():
		_host_choose_quest(multiplayer.get_remote_sender_id(), quest_id)


@rpc("authority", "call_remote", "reliable")
func _receive_quest_choice(quest_id: int) -> void:
	if Quests.is_valid_id(quest_id):
		_show_quest_choice(quest_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_buy(relic_id: int) -> void:
	if multiplayer.is_server():
		_host_buy(multiplayer.get_remote_sender_id(), relic_id, _ready_peers_for_host())


@rpc("any_peer", "call_remote", "reliable")
func _request_reroll() -> void:
	if multiplayer.is_server():
		_host_reroll(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _request_ready() -> void:
	if multiplayer.is_server():
		_host_ready(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func _receive_relic_bought(peer_id: int, relic_id: int) -> void:
	if Relics.is_valid_id(relic_id):
		relic_bought.emit(peer_id, relic_id)


@rpc("authority", "call_remote", "reliable")
func _receive_relic_history(peer_id: int, ids: PackedInt32Array) -> void:
	for id: int in ids:
		if Relics.is_valid_id(id):
			relic_bought.emit(peer_id, id)
