class_name LevelUpController
extends Node
## Runs the level-up pause across the network.
##
## Host: queues level-ups, rolls each player's cards (Cards), collects picks
## (its own and from clients), handles card rerolls, and announces every card a
## player gets: level-up picks, and (host_grant) altars, chests and evolutions.
## Everyone: shows this machine's choice cards and sends the local pick.
## The arena owns the phase (PLAYING / LEVEL_UP); this node owns the pause itself.

## Every peer: apply this card to that player (the arena does the applying).
signal card_announced(peer_id: int, card: int)

## Autopilot (test mode) picks after a random delay in this range, in seconds.
const AUTOPILOT_PICK_DELAY_MIN: float = 0.3
const AUTOPILOT_PICK_DELAY_MAX: float = 1.5

## Host: level-ups earned but not yet chosen.
var pending_levels: int = 0
## Peers still choosing (host: from the session; clients: from snapshots).
var waiting_ids: Array[int] = []
## Seconds left after the first pick; negative = not started.
var countdown_left: float = -1.0

var _session: LevelUpSession = LevelUpSession.new()
var _round_active: bool = false
## The level this round is for (cards resent after a reroll show it again).
var _round_level: int = 1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _panel: LevelUpPanel = null
## Returns this machine's Player (or null), for the cards' stat preview.
var _local_player: Callable = func() -> Player: return null
## Host: peer id -> Player (or null), for rerolls; and the clients whose arena has loaded.
var _find_player: Callable = func(_peer_id: int) -> Player: return null
var _get_ready_peers: Callable = func() -> Array[int]: return []
## This machine's open choices (empty = nothing to pick right now).
var _my_choices: Array[int] = []
var _my_pick_sent: bool = false
## What this machine picked this round (for the status line).
var _my_pick: int = -1


func _ready() -> void:
	_rng.randomize()


func bind_panel(panel: LevelUpPanel, local_player: Callable, find_player: Callable = Callable(),
		get_ready_peers: Callable = Callable()) -> void:
	_panel = panel
	_local_player = local_player
	if find_player.is_valid():
		_find_player = find_player
	if get_ready_peers.is_valid():
		_get_ready_peers = get_ready_peers
	_panel.picked.connect(_pick_locally)
	_panel.reroll_pressed.connect(request_reroll)


## True while this machine has cards to choose from (picked or not).
func has_local_choices() -> bool:
	return not _my_choices.is_empty()


# --- Host ----------------------------------------------------------------------

func host_queue(levels: int) -> void:
	pending_levels += levels


func host_should_start() -> bool:
	return pending_levels > 0 and not _round_active


## Starts a round. `players` are everyone currently in the game; `ready_peers`
## are the clients able to receive messages.
func host_start(players: Array[Player], level: int, ready_peers: Array[int]) -> void:
	var offered: Dictionary[int, Array] = {}
	for player: Player in players:
		var reachable := player.peer_id == multiplayer.get_unique_id() or ready_peers.has(player.peer_id)
		if not reachable:
			continue
		var choices := Cards.roll(_rng, player, player.health.hp < player.health.max_hp)
		if not choices.is_empty():
			offered[player.peer_id] = choices
	_session.start(offered)
	_round_active = true
	_round_level = level
	_refresh_host_status()
	for peer_id: int in offered:
		_send_choices(peer_id)


func _send_choices(peer_id: int) -> void:
	var choices: Array[int] = []
	choices.assign(_session.choices[peer_id])
	var player: Player = _find_player.call(peer_id)
	var rerolls := player.card_rerolls if player != null else 0
	if peer_id == multiplayer.get_unique_id():
		_show_choices(_round_level, choices, rerolls)
	else:
		_receive_choices.rpc_id(peer_id, _round_level, PackedInt32Array(choices), rerolls)


## Advances the round. Returns true when this round is over (picks announced).
func host_tick(delta: float, ready_peers: Array[int]) -> bool:
	if not _round_active:
		return true
	_session.tick(delta)
	_refresh_host_status()
	if not _session.is_finished():
		return false
	var results := _session.final_picks(_rng)
	for peer_id: int in results:
		card_announced.emit(peer_id, results[peer_id])
		for target: int in ready_peers:
			_receive_upgrade_applied.rpc_id(target, peer_id, results[peer_id])
	pending_levels = maxi(pending_levels - 1, 0)
	_round_active = false
	close_local()
	return true


func host_remove_player(peer_id: int) -> void:
	_session.remove(peer_id)


## Host: give a player a card outside a level-up (altars, chests, evolutions,
## test flags), announced the same way as a real pick.
func host_grant(peer_id: int, card: int, ready_peers: Array[int]) -> void:
	if not Cards.is_valid(card):
		return
	card_announced.emit(peer_id, card)
	for target: int in ready_peers:
		_receive_upgrade_applied.rpc_id(target, peer_id, card)


## Host: tell a late joiner about every card each player already has (their
## whole build, replayed in order) and their rerolls.
func host_send_history(to_peer: int, players: Array[Player]) -> void:
	for player: Player in players:
		if not player.card_history.is_empty():
			_receive_upgrade_history.rpc_id(to_peer, player.peer_id, PackedInt32Array(player.card_history))
		_receive_rerolls.rpc_id(to_peer, player.peer_id, player.card_rerolls)


## Host: a player got one more card reroll (bought in the shop).
func host_add_reroll(peer_id: int, ready_peers: Array[int]) -> void:
	var player: Player = _find_player.call(peer_id)
	if player != null:
		_set_rerolls(player, player.card_rerolls + 1, ready_peers)


func _set_rerolls(player: Player, count: int, ready_peers: Array[int]) -> void:
	player.card_rerolls = count
	for target: int in ready_peers:
		_receive_rerolls.rpc_id(target, player.peer_id, count)


## Host: swap this player's cards for new ones, if they have a reroll and haven't picked.
func _host_reroll(peer_id: int, ready_peers: Array[int]) -> void:
	var player: Player = _find_player.call(peer_id)
	if player == null or player.card_rerolls <= 0 or not _round_active:
		return
	if not _session.choices.has(peer_id) or _session.picks.has(peer_id):
		return
	_set_rerolls(player, player.card_rerolls - 1, ready_peers)
	_session.choices[peer_id] = Cards.roll(_rng, player, player.health.hp < player.health.max_hp)
	_send_choices(peer_id)


func host_reset() -> void:
	pending_levels = 0
	_round_active = false
	waiting_ids.clear()
	countdown_left = -1.0
	close_local()


# --- Everyone ------------------------------------------------------------------

## Client: status from a host snapshot.
func apply_status(waiting: PackedInt32Array, countdown: float) -> void:
	waiting_ids.assign(waiting)
	countdown_left = countdown


## Hides the cards (the round ended).
func close_local() -> void:
	_my_choices.clear()
	_my_pick_sent = false
	if _panel != null:
		_panel.hide()


## Status line under the cards / in the banner.
func status_text(name_of: Callable) -> String:
	var parts := PackedStringArray()
	if has_local_choices() and not _my_pick_sent:
		parts.append("Pick one!")
	elif not waiting_ids.is_empty():
		var names := PackedStringArray()
		for peer_id: int in waiting_ids:
			# The host's list can lag our own pick by a snapshot.
			if not (_my_pick_sent and peer_id == multiplayer.get_unique_id()):
				names.append(name_of.call(peer_id))
		if _my_pick_sent and Cards.is_valid(_my_pick):
			var me := _local_player.call() as Player
			parts.append("You chose %s." % Cards.title(_my_pick, me.stats if me != null else null))
		if not names.is_empty():
			parts.append("Waiting for %s" % ", ".join(names))
	if countdown_left >= 0.0:
		parts.append("%ds left" % ceili(countdown_left))
	return "   ".join(parts)


func refresh_panel_status(name_of: Callable) -> void:
	if _panel != null and _panel.visible:
		_panel.set_status(status_text(name_of))


func _show_choices(level: int, choices: Array[int], rerolls: int = 0) -> void:
	_my_choices = choices
	_my_pick_sent = false
	if _panel != null:
		_panel.open(level, choices, _local_player.call() as Player, rerolls)
	if LaunchOptions.autopilot and not choices.is_empty():
		var delay := _rng.randf_range(AUTOPILOT_PICK_DELAY_MIN, AUTOPILOT_PICK_DELAY_MAX)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if has_local_choices() and not _my_pick_sent:
				_pick_locally(_my_choices[_rng.randi() % _my_choices.size()]))


func _pick_locally(card: int) -> void:
	if _my_pick_sent or not _my_choices.has(card):
		return
	_my_pick_sent = true
	_my_pick = card
	if _panel != null:
		_panel.mark_picked(card)
	if multiplayer.is_server():
		_session.pick(multiplayer.get_unique_id(), card)
		_refresh_host_status()
	else:
		_submit_pick.rpc_id(1, card)


## The Reroll button: new cards for this player (uses one reroll).
func request_reroll() -> void:
	if _my_pick_sent or _my_choices.is_empty():
		return
	if multiplayer.is_server():
		_host_reroll(multiplayer.get_unique_id(), _all_ready_peers())
	else:
		_request_reroll.rpc_id(1)


## Host: the clients whose arena has loaded (only they get messages).
func _all_ready_peers() -> Array[int]:
	var peers: Array[int] = []
	peers.assign(_get_ready_peers.call())
	return peers


func _refresh_host_status() -> void:
	waiting_ids = _session.waiting_for()
	countdown_left = _session.countdown_left


# --- Network messages ------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _receive_choices(level: int, ids: PackedInt32Array, rerolls: int) -> void:
	var choices: Array[int] = []
	for id: int in ids:
		if Cards.is_valid(id):
			choices.append(id)
	_show_choices(level, choices, rerolls)


@rpc("any_peer", "call_remote", "reliable")
func _request_reroll() -> void:
	if multiplayer.is_server():
		_host_reroll(multiplayer.get_remote_sender_id(), _all_ready_peers())


@rpc("authority", "call_remote", "reliable")
func _receive_rerolls(peer_id: int, count: int) -> void:
	var player: Player = _find_player.call(peer_id)
	if player != null:
		player.card_rerolls = count
	if _panel != null and _panel.visible and player != null and player.is_local():
		_panel.set_rerolls(count)


@rpc("any_peer", "call_remote", "reliable")
func _submit_pick(upgrade_id: int) -> void:
	if multiplayer.is_server():
		_session.pick(multiplayer.get_remote_sender_id(), upgrade_id)
		_refresh_host_status()


@rpc("authority", "call_remote", "reliable")
func _receive_upgrade_applied(peer_id: int, card: int) -> void:
	if Cards.is_valid(card):
		card_announced.emit(peer_id, card)


@rpc("authority", "call_remote", "reliable")
func _receive_upgrade_history(peer_id: int, cards: PackedInt32Array) -> void:
	for card: int in cards:
		if Cards.is_valid(card):
			card_announced.emit(peer_id, card)
