extends Node
## Network session autoload (reach it anywhere as `Net`).
##
## Wraps Godot's high-level multiplayer API. Every node shares one `multiplayer`
## object; this script only decides which "peer" (connection type) it uses:
## - Solo:   OfflineMultiplayerPeer. Acts like a host with nobody connected.
## - Host:   ENet server. The host is always peer id 1 and owns the game state.
## - Client: ENet client connected to a host by IP address.

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4

## Host only: public invite address and router port status.
var invite: HostInvite = HostInvite.new()


func _ready() -> void:
	add_child(invite)


func start_solo() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


## With `reach_internet`, also opens the router port and looks up the invite address.
func host_game(port: int, reach_internet: bool = true) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
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
