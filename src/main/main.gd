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
var _feedback: FeedbackScreen = null


func _ready() -> void:
	_menu.solo_requested.connect(_start_solo)
	_menu.host_requested.connect(_start_host)
	_menu.join_requested.connect(_start_join)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_pause_menu.leave_requested.connect(_leave_game.bind("You left the game."))
	_feedback = FeedbackScreen.new()
	add_child(_feedback)
	_menu.feedback_requested.connect(func() -> void: _feedback.open(null, _feedback_context()))
	_pause_menu.feedback_requested.connect(_open_feedback_from_pause)
	_feedback.closed.connect(func() -> void:
		if _menu.visible:
			_menu.show_panel_after_feedback()
		elif _level.get_child_count() > 0:
			_pause_menu.show_after_feedback())
	_menu.show_menu()
	Music.play(&"menu")
	# Every button anywhere clicks softly when pressed (menus, cards, shop).
	get_tree().node_added.connect(func(node: Node) -> void:
		var button := node as BaseButton
		if button != null:
			button.pressed.connect(func() -> void: Sfx.play(&"ui", -8.0)))
	_apply_launch_options()


## From the pause menu: hide it for a moment so the screenshot shows the game.
func _open_feedback_from_pause() -> void:
	_pause_menu.hide()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	_feedback.open(image, _feedback_context())


## Version, OS and where the player is (title menu, lobby, or the arena's details).
func _feedback_context() -> String:
	var where := "Title menu"
	var arena := _level.get_node_or_null("Arena") as Arena
	if arena != null:
		where = arena.feedback_context()
	elif _level.get_node_or_null("Lobby") != null:
		where = "In the lobby (%s)" % ("host" if multiplayer.is_server() else "client")
	return "%s, %s\n%s" % [BuildInfo.describe(), OS.get_name(), where]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _menu.visible and not _pause_menu.visible \
			and not _feedback.visible and _level.get_child_count() > 0:
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
		if LaunchOptions.mode == LaunchOptions.Mode.MENU:
			get_tree().create_timer(0.5).timeout.connect(func() -> void: save_screenshot(get_tree(), "title.png"))
			get_tree().create_timer(0.8).timeout.connect(_screenshot_info_pages)
		_take_screenshots_periodically()
	if LaunchOptions.run_for_seconds > 0.0:
		get_tree().create_timer(LaunchOptions.run_for_seconds).timeout.connect(_report_and_quit)


## Screenshot mode on the title screen: a picture of each Compendium tab and the
## Playtest Checklist, then back to the menu.
func _screenshot_info_pages() -> void:
	var compendium := _menu.compendium
	compendium.open()
	var tabs := compendium.find_children("*", "Button", true, false).filter(
		func(button: Node) -> bool: return button.get_parent() != compendium.footer)
	for i: int in tabs.size():
		(tabs[i] as Button).pressed.emit()
		await get_tree().create_timer(0.2).timeout
		await save_screenshot(get_tree(), "compendium_%d.png" % i)
	compendium.close()
	_menu.checklist.open()
	await get_tree().create_timer(0.2).timeout
	await save_screenshot(get_tree(), "checklist.png")
	_menu.checklist.close()
	_menu.records.open()
	await get_tree().create_timer(0.2).timeout
	await save_screenshot(get_tree(), "records.png")
	_menu.records.close()
	_menu.open_settings()
	await get_tree().create_timer(0.2).timeout
	await save_screenshot(get_tree(), "settings.png")
	_menu.show_menu()
	_feedback.open(null, _feedback_context())
	await get_tree().create_timer(0.2).timeout
	await save_screenshot(get_tree(), "feedback_title.png")
	_feedback.close()


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
		await save_screenshot(get_tree(), "gameplay_%02d.png" % index)
		if index == 2 and _level.get_node_or_null("Arena") != null:
			# The feedback screen as opened from the pause menu, once.
			_pause_menu.open()
			await _open_feedback_from_pause()
			await get_tree().create_timer(0.3).timeout
			await save_screenshot(get_tree(), "feedback_ingame.png")
			_feedback.close()
			_pause_menu.close()


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
	Music.play(&"menu")
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
	Music.play(&"menu")
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
