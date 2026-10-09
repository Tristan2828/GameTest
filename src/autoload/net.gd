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


func start_solo() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func host_game(port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
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
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func is_online() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer


## Round-trip time to the host in milliseconds (clients only; 0 otherwise).
func ping_ms() -> int:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or multiplayer.is_server():
		return 0
	var host_peer := enet.get_peer(1)
	if host_peer == null:
		return 0
	return int(host_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
