extends Node
## Network session autoload (reach it anywhere as `Net`).
##
## Wraps Godot's high-level multiplayer API. Every node shares one `multiplayer`
## object; this script only decides which "peer" (connection type) it uses:
## - Solo:   OfflineMultiplayerPeer. Acts like a host with nobody connected.
## - Host:   ENet server. The host is always peer id 1 and owns the game state.
## - Client: ENet client connected to a host by IP address.
##
## It also keeps everyone's display names (typed on the title menu): a client
## sends its name to the host on connecting, and the host sends the full list to
## everyone whenever it changes. (An autoload has the same node path on every
## peer, so its RPCs work in the menu, the lobby and the arena alike.)

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4

## Host only: public invite address and router port status.
var invite: HostInvite = HostInvite.new()
## peer id -> chosen display name ("" or missing = called by slot color).
## The host's copy is the truth; clients get it from _receive_names.
var names: Dictionary[int, String] = {}

## The name list changed (someone joined, left or sent their name).
signal names_changed


func _ready() -> void:
	add_child(invite)
	multiplayer.connected_to_server.connect(func() -> void:
		_register_name.rpc_id(1, Settings.player_name))
	multiplayer.peer_disconnected.connect(func(peer_id: int) -> void:
		if multiplayer.is_server() and names.erase(peer_id):
			_broadcast_names())


## A player's name as shown everywhere: their chosen name, or their slot color.
func name_of(peer_id: int, slot: int) -> String:
	return PlayerNames.display(names.get(peer_id, ""), slot)


func _set_own_name() -> void:
	names.clear()
	names[1] = PlayerNames.sanitize(Settings.player_name)
	names_changed.emit()


func start_solo() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_set_own_name()


## With `reach_internet`, also opens the router port and looks up the invite address.
func host_game(port: int, reach_internet: bool = true) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_set_own_name()
	if reach_internet:
		invite.start(port)
	return OK


## Starts connecting. Success or failure arrives later through
## `multiplayer.connected_to_server` / `multiplayer.connection_failed`.
func join_game(address: String, port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave_game() -> void:
	invite.stop()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	names.clear()
	names_changed.emit()


func is_online() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer


## Splits a pasted invite like "203.0.113.5:7777" or "host.example.com:7777" into
## address and port. Text without a port uses `default_port`.
static func parse_invite(text: String, default_port: int) -> Dictionary:
	var cleaned := text.strip_edges()
	var port := default_port
	# Exactly one colon means "address:port". (Several colons would be an IPv6 address.)
	if cleaned.count(":") == 1:
		var port_text := cleaned.get_slice(":", 1)
		cleaned = cleaned.get_slice(":", 0)
		if port_text.is_valid_int() and port_text.to_int() > 0 and port_text.to_int() <= 65535:
			port = port_text.to_int()
	return {"address": cleaned, "port": port}


## Round-trip time to the host in milliseconds (clients only; 0 otherwise).
func ping_ms() -> int:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or multiplayer.is_server():
		return 0
	var host_peer := enet.get_peer(1)
	if host_peer == null:
		return 0
	return int(host_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


# --- Names ---------------------------------------------------------------------

func _broadcast_names() -> void:
	var ids := PackedInt32Array()
	var list := PackedStringArray()
	for peer_id: int in names:
		ids.append(peer_id)
		list.append(names[peer_id])
	names_changed.emit()
	for peer_id: int in multiplayer.get_peers():
		# The count keeps the call valid even if both arrays were empty.
		_receive_names.rpc_id(peer_id, ids.size(), ids, list)


## Client -> host, once on connecting.
@rpc("any_peer", "call_remote", "reliable")
func _register_name(chosen: String) -> void:
	if not multiplayer.is_server():
		return
	names[multiplayer.get_remote_sender_id()] = PlayerNames.sanitize(chosen)
	_broadcast_names()


@rpc("authority", "call_remote", "reliable")
func _receive_names(count: int, ids: PackedInt32Array, list: PackedStringArray) -> void:
	names.clear()
	for i: int in mini(count, mini(ids.size(), list.size())):
		names[ids[i]] = list[i]
	names_changed.emit()
