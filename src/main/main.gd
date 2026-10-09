extends Node
## Root scene. Shows the main menu, starts solo/host/join sessions, and owns the
## `Level` slot. The host puts the arena into that slot; `LevelSpawner` (a
## MultiplayerSpawner) then recreates it automatically on every client, including
## friends who join later.

const ARENA_SCENE: PackedScene = preload("res://src/arena/arena.tscn")

@onready var _level: Node = $Level
@onready var _menu: MainMenu = $MainMenu


func _ready() -> void:
	_menu.solo_requested.connect(_start_solo)
	_menu.host_requested.connect(_start_host)
	_menu.join_requested.connect(_start_join)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_menu.show_menu()
	_apply_launch_options()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _menu.visible:
		_leave_game("You left the game.")


func _apply_launch_options() -> void:
	LaunchOptions.parse(OS.get_cmdline_user_args())
	match LaunchOptions.mode:
		LaunchOptions.Mode.SOLO:
			_start_solo()
		LaunchOptions.Mode.HOST:
			_start_host(LaunchOptions.port)
		LaunchOptions.Mode.JOIN:
			var invite: Dictionary = Net.parse_invite(LaunchOptions.address, LaunchOptions.port)
			_start_join(invite["address"], invite["port"])
	if LaunchOptions.run_for_seconds > 0.0:
		get_tree().create_timer(LaunchOptions.run_for_seconds).timeout.connect(_report_and_quit)


func _start_solo() -> void:
	Net.start_solo()
	_load_arena()


func _start_host(port: int) -> void:
	var err: Error = Net.host_game(port, not LaunchOptions.local_only)
	if err != OK:
		_menu.show_menu("Could not host on port %d: %s" % [port, error_string(err)])
		return
	print("Hosting on port %d" % port)
	_load_arena()


func _start_join(address: String, port: int) -> void:
	var err: Error = Net.join_game(address, port)
	if err != OK:
		_menu.show_menu("Could not connect: %s" % error_string(err))
		return
	_menu.show_busy("Connecting to %s:%d..." % [address, port])


func _on_connected_to_server() -> void:
	# Nothing to load here: the host's LevelSpawner sends us the arena.
	print("Connected as peer %d" % multiplayer.get_unique_id())
	_menu.hide()


func _on_connection_failed() -> void:
	Net.leave_game()
	_menu.show_menu("Could not connect to the host.")


func _on_server_disconnected() -> void:
	_leave_game("Disconnected from the host.")


func _load_arena() -> void:
	_menu.hide()
	var arena: Arena = ARENA_SCENE.instantiate()
	# Deferred: swap arenas after the current frame, not in the middle of its tick.
	arena.restart_requested.connect(_restart_arena, CONNECT_DEFERRED)
	_level.add_child(arena)


## Host: replace the arena with a fresh one. LevelSpawner removes the old arena
## and creates the new one on every client too.
func _restart_arena() -> void:
	for child: Node in _level.get_children():
		_level.remove_child(child)
		child.queue_free()
	_load_arena()


func _leave_game(message: String) -> void:
	Net.leave_game()
	for child: Node in _level.get_children():
		_level.remove_child(child)
		child.queue_free()
	_menu.show_menu(message)


func _report_and_quit() -> void:
	var arena := _level.get_node_or_null("Arena") as Arena
	if arena != null:
		print(arena.debug_report())
	else:
		print("[report] peer %d: no arena loaded" % multiplayer.get_unique_id())
	Net.leave_game()
	get_tree().quit()
