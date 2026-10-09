class_name Updater
extends Node
## Checks GitHub for a newer release when the title screen opens and, when asked,
## updates the game in place:
##   1. download the release zip (user://update/),
##   2. take GameTest.exe out of it and write it next to the running exe,
##   3. rename the running exe to "<name>.old" (Windows allows renaming a running
##      exe, not overwriting it) and the new one into its place,
##   4. start the new exe and quit. The next start deletes the ".old" file.
## Only in the exported game: never from the editor, tests or automated runs.
## If anything fails, the menu offers the release page in the browser instead.

signal changed

enum State { OFF, CHECKING, UP_TO_DATE, AVAILABLE, DOWNLOADING, INSTALLING, FAILED, CHECK_FAILED }

const DOWNLOAD_PATH: String = "user://update/latest.zip"
const OLD_SUFFIX: String = ".old"
const NEW_SUFFIX: String = ".new"

var state: State = State.OFF
var latest: ReleaseInfo = null
## Why it failed, for the menu.
var error: String = ""

var _http: HTTPRequest = null


## True when this copy of the game can update itself (a real exported build,
## online use, not a test run).
static func can_run() -> bool:
	return OS.has_feature("template") and OS.get_name() == "Windows" \
		and DisplayServer.get_name() != "headless" and not LaunchOptions.local_only \
		and not LaunchOptions.autopilot


func _ready() -> void:
	if not can_run():
		return
	_delete_leftovers()
	check()


## 0..1 while downloading.
func progress() -> float:
	if _http == null or state != State.DOWNLOADING:
		return 0.0
	var total := maxi(_http.get_body_size(), latest.zip_size if latest != null else 0)
	return clampf(float(_http.get_downloaded_bytes()) / maxf(total, 1.0), 0.0, 1.0)


func check() -> void:
	_set_state(State.CHECKING)
	_request(ReleaseInfo.LATEST_URL, "", _on_checked)


## Downloads and installs the newer version (then restarts the game).
func update() -> void:
	if state != State.AVAILABLE and state != State.FAILED:
		return
	if latest == null or latest.zip_url.is_empty():
		_fail("The new release has no Windows download yet.")
		return
	DirAccess.make_dir_recursive_absolute(DOWNLOAD_PATH.get_base_dir())
	_set_state(State.DOWNLOADING)
	_request(latest.zip_url, DOWNLOAD_PATH, _on_downloaded)


## The release page in the browser (manual fallback).
func open_release_page() -> void:
	var url := latest.page_url if latest != null and not latest.page_url.is_empty() \
		else "https://github.com/%s/releases/latest" % ReleaseInfo.REPO
	OS.shell_open(url)


func _process(_delta: float) -> void:
	if state == State.DOWNLOADING:
		changed.emit()  # Progress bar.


func _request(url: String, save_to: String, done: Callable) -> void:
	if _http != null:
		_http.queue_free()
	_http = HTTPRequest.new()
	_http.download_file = save_to
	_http.timeout = 0.0 if not save_to.is_empty() else 15.0
	add_child(_http)
	_http.request_completed.connect(done, CONNECT_ONE_SHOT)
	# GitHub's API requires a User-Agent.
	var err := _http.request(url, PackedStringArray(["User-Agent: GameTest-updater", "Accept: application/vnd.github+json"]))
	if err != OK:
		done.call(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())


func _on_checked(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		error = "Couldn't reach GitHub to check for updates."
		_set_state(State.CHECK_FAILED)
		return
	latest = ReleaseInfo.parse(body.get_string_from_utf8())
	if latest == null:
		error = "Couldn't read the latest release."
		_set_state(State.CHECK_FAILED)
	elif ReleaseInfo.compare_versions(latest.version, ReleaseInfo.current_version()) > 0:
		_set_state(State.AVAILABLE)
		if LaunchOptions.update_now:
			update()  # Test aid: the end-to-end update check.
	else:
		_set_state(State.UP_TO_DATE)


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("Download failed (%s)." % ("HTTP %d" % code if result == HTTPRequest.RESULT_SUCCESS else "network error"))
		return
	_set_state(State.INSTALLING)
	await get_tree().process_frame  # Let the menu show "Installing..." first.
	var problem := _install(ProjectSettings.globalize_path(DOWNLOAD_PATH), OS.get_executable_path())
	if not problem.is_empty():
		_fail(problem)
		return
	OS.create_process(OS.get_executable_path(), [])
	get_tree().quit()


## Swaps the exe from the zip in for `exe_path`. Returns "" or what went wrong
## (the old exe is put back if the swap fails halfway).
static func _install(zip_path: String, exe_path: String) -> String:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return "The download is damaged."
	var exe_name := ""
	for entry: String in zip.get_files():
		if entry.get_file().to_lower() == "gametest.exe":
			exe_name = entry
	if exe_name.is_empty():
		zip.close()
		return "The download has no GameTest.exe."
	var bytes := zip.read_file(exe_name)
	zip.close()
	if bytes.size() < 1_000_000:
		return "The downloaded game looks incomplete."
	var new_path := exe_path + NEW_SUFFIX
	var file := FileAccess.open(new_path, FileAccess.WRITE)
	if file == null:
		return "Can't write next to the game (is the folder read-only?)."
	file.store_buffer(bytes)
	file.close()
	var old_path := exe_path + OLD_SUFFIX
	if FileAccess.file_exists(old_path):
		DirAccess.remove_absolute(old_path)
	if DirAccess.rename_absolute(exe_path, old_path) != OK:
		DirAccess.remove_absolute(new_path)
		return "Windows didn't let the game replace itself."
	if DirAccess.rename_absolute(new_path, exe_path) != OK:
		DirAccess.rename_absolute(old_path, exe_path)
		return "Couldn't put the new version in place."
	return ""


## The previous exe (renamed during an update) and the downloaded zip.
func _delete_leftovers() -> void:
	var old_path := OS.get_executable_path() + OLD_SUFFIX
	if FileAccess.file_exists(old_path):
		DirAccess.remove_absolute(old_path)  # May fail while the old game is still closing; next time then.
	if FileAccess.file_exists(DOWNLOAD_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DOWNLOAD_PATH))


func _fail(message: String) -> void:
	error = message
	_set_state(State.FAILED)


func _set_state(new_state: State) -> void:
	state = new_state
	changed.emit()
