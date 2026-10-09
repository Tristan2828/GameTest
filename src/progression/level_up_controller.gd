class_name LevelUpController
extends Node
## Runs the level-up pause across the network.
##
## Host: queues level-ups, rolls each player's choices, collects picks (its own
## and from clients), and announces the final pick for every player.
## Everyone: shows this machine's choice cards and sends the local pick.
## The arena owns the phase (PLAYING / LEVEL_UP); this node owns the pause itself.

## Every peer: apply this upgrade to that player (the arena does the applying).
signal upgrade_announced(peer_id: int, upgrade_id: int)

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
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _panel: LevelUpPanel = null
## This machine's open choices (empty = nothing to pick right now).
var _my_choices: Array[int] = []
var _my_pick_sent: bool = false


func _ready() -> void:
	_rng.randomize()


func bind_panel(panel: LevelUpPanel) -> void:
	_panel = panel
	_panel.picked.connect(_pick_locally)


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
		var is_hurt := player.health.hearts < player.health.max_hearts
		var choices := Upgrades.roll(_rng, player.upgrade_ids, is_hurt)
		if not choices.is_empty():
			offered[player.peer_id] = choices
	_session.start(offered)
	_round_active = true
	_refresh_host_status()
	for peer_id: int in offered:
		var choices: Array[int] = []
		choices.assign(offered[peer_id])
		if peer_id == multiplayer.get_unique_id():
			_show_choices(level, choices)
		else:
			_receive_choices.rpc_id(peer_id, level, PackedInt32Array(choices))


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
		upgrade_announced.emit(peer_id, results[peer_id])
		for target: int in ready_peers:
			_receive_upgrade_applied.rpc_id(target, peer_id, results[peer_id])
	pending_levels = maxi(pending_levels - 1, 0)
	_round_active = false
	close_local()
	return true


func host_remove_player(peer_id: int) -> void:
	_session.remove(peer_id)


## Host: tell a late joiner about every upgrade each player already has.
func host_send_history(to_peer: int, players: Array[Player]) -> void:
	for player: Player in players:
		if not player.upgrade_ids.is_empty():
			_receive_upgrade_history.rpc_id(to_peer, player.peer_id, PackedInt32Array(player.upgrade_ids))


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
			names.append(name_of.call(peer_id))
		parts.append("Waiting for %s" % ", ".join(names))
	if countdown_left >= 0.0:
		parts.append("%ds left" % ceili(countdown_left))
	return "   ".join(parts)


func refresh_panel_status(name_of: Callable) -> void:
	if _panel != null and _panel.visible:
		_panel.set_status(status_text(name_of))


func _show_choices(level: int, choices: Array[int]) -> void:
	_my_choices = choices
	_my_pick_sent = false
	if _panel != null:
		_panel.open(level, choices)
	if LaunchOptions.autopilot and not choices.is_empty():
		var delay := _rng.randf_range(AUTOPILOT_PICK_DELAY_MIN, AUTOPILOT_PICK_DELAY_MAX)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if has_local_choices() and not _my_pick_sent:
				_pick_locally(_my_choices[_rng.randi() % _my_choices.size()]))


func _pick_locally(upgrade_id: int) -> void:
	if _my_pick_sent or not _my_choices.has(upgrade_id):
		return
	_my_pick_sent = true
	if multiplayer.is_server():
		_session.pick(multiplayer.get_unique_id(), upgrade_id)
		_refresh_host_status()
	else:
		_submit_pick.rpc_id(1, upgrade_id)


func _refresh_host_status() -> void:
	waiting_ids = _session.waiting_for()
	countdown_left = _session.countdown_left


# --- Network messages ------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _receive_choices(level: int, ids: PackedInt32Array) -> void:
	var choices: Array[int] = []
	for id: int in ids:
		if Upgrades.is_valid_id(id):
			choices.append(id)
	_show_choices(level, choices)


@rpc("any_peer", "call_remote", "reliable")
func _submit_pick(upgrade_id: int) -> void:
	if multiplayer.is_server():
		_session.pick(multiplayer.get_remote_sender_id(), upgrade_id)
		_refresh_host_status()


@rpc("authority", "call_remote", "reliable")
func _receive_upgrade_applied(peer_id: int, upgrade_id: int) -> void:
	if Upgrades.is_valid_id(upgrade_id):
		upgrade_announced.emit(peer_id, upgrade_id)


@rpc("authority", "call_remote", "reliable")
func _receive_upgrade_history(peer_id: int, ids: PackedInt32Array) -> void:
	for id: int in ids:
		if Upgrades.is_valid_id(id):
			upgrade_announced.emit(peer_id, id)
