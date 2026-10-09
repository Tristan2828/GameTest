class_name Main
extends Node
## Root scene. Shows the main menu, starts solo/host/join sessions, and owns the
## `Level` slot. The host puts the lobby or the arena into that slot;
## `LevelSpawner` (a MultiplayerSpawner) then recreates it automatically on every
## client, including friends who join later.

const ARENA_SCENE: PackedScene = preload("res://src/arena/arena.tscn")
const LOBBY_SCENE: PackedScene = preload("res://src/lobby/lobby.tscn")

@onready var _level: Node = $Level
@onready var _menu: MainMenu = $MainMenu
@onready var _pause_menu: PauseMenu = $PauseMenu


func _ready() -> void:
	_menu.solo_requested.connect(_start_solo)
	_menu.host_requested.connect(_start_host)
	_menu.join_requested.connect(_start_join)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_pause_menu.leave_requested.connect(_leave_game.bind("You left the game."))
	_menu.show_menu()
	_apply_launch_options()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _menu.visible and not _pause_menu.visible \
			and _level.get_child_count() > 0:
		_pause_menu.open()
		get_viewport().set_input_as_handled()


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
	if not LaunchOptions.screenshot_dir.is_empty():
		_take_screenshots_periodically()
	if LaunchOptions.run_for_seconds > 0.0:
		get_tree().create_timer(LaunchOptions.run_for_seconds).timeout.connect(_report_and_quit)


func _apply_character_flag() -> void:
	if Characters.is_valid_id(LaunchOptions.character):
		RunSetup.characters[1] = LaunchOptions.character


## Saves the screen to the --screenshot-dir folder (debug aid).
static func save_screenshot(tree: SceneTree, file_name: String) -> void:
	if LaunchOptions.screenshot_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := LaunchOptions.screenshot_dir.path_join(file_name)
	tree.root.get_texture().get_image().save_png(path)
	print("Saved screenshot %s" % path)


func _take_screenshots_periodically() -> void:
	var index := 0
	while is_inside_tree():
		await get_tree().create_timer(10.0).timeout
		index += 1
		save_screenshot(get_tree(), "gameplay_%02d.png" % index)


func _start_solo() -> void:
	Net.start_solo()
	_apply_character_flag()
	_load_lobby()


func _start_host(port: int) -> void:
	var err: Error = Net.host_game(port, not LaunchOptions.local_only)
	if err != OK:
		_menu.show_menu("Could not host on port %d: %s" % [port, error_string(err)])
		return
	print("Hosting on port %d" % port)
	_apply_character_flag()
	_load_lobby()


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


## Host: show the lobby (start of a session, and after every run).
func _load_lobby() -> void:
	_clear_level()
	_menu.hide()
	var lobby: Lobby = LOBBY_SCENE.instantiate()
	# Deferred: swap scenes after the current frame, never in the middle of one.
	lobby.start_requested.connect(_load_arena, CONNECT_DEFERRED)
	_level.add_child(lobby)


## Host: start a run. LevelSpawner removes the old scene and creates the new one
## on every client too.
func _load_arena() -> void:
	_clear_level()
	_menu.hide()
	var arena: Arena = ARENA_SCENE.instantiate()
	arena.restart_requested.connect(_load_lobby, CONNECT_DEFERRED)
	_level.add_child(arena)


func _clear_level() -> void:
	for child: Node in _level.get_children():
		_level.remove_child(child)
		child.queue_free()


func _leave_game(message: String) -> void:
	_pause_menu.close()
	Net.leave_game()
	for child: Node in _level.get_children():
		_level.remove_child(child)
		child.queue_free()
	_menu.show_menu(message)


func _report_and_quit() -> void:
	var arena := _level.get_node_or_null("Arena") as Arena
	var lobby := _level.get_node_or_null("Lobby") as Lobby
	if arena != null:
		print(arena.debug_report())
	elif lobby != null:
		print(lobby.debug_report())
	else:
		print("[report] peer %d: no arena loaded" % multiplayer.get_unique_id())
	Net.leave_game()
	get_tree().quit()
