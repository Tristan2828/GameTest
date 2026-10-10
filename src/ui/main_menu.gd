class_name MainMenu
extends CanvasLayer
## Title menu: your display name, play solo, host a game, or join a host by IP
## address, and Exit Game. Also opens
## Settings, the Game Guide (`Compendium`: info on heroes, weapons, items, enemies), Records
## (your best runs on this PC) and the
## Playtest Checklist (what still needs testing, from docs/PLAYTEST.md).
## In the exported game it also checks GitHub for a newer version and offers an
## Update button (see Updater).

signal solo_requested
signal host_requested(port: int)
signal join_requested(address: String, port: int)
signal feedback_requested

@onready var _solo_button: Button = %SoloButton
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _port_edit: LineEdit = %PortEdit
@onready var _status_label: Label = %StatusLabel
@onready var _version_label: Label = %VersionLabel
@onready var _settings_button: Button = %SettingsButton
@onready var _settings: SettingsPanel = %Settings
@onready var _compendium_button: Button = %CompendiumButton
@onready var _checklist_button: Button = %ChecklistButton
@onready var _records_button: Button = %RecordsButton
@onready var _feedback_button: Button = %FeedbackButton
@onready var _exit_button: Button = %ExitButton
@onready var _name_edit: LineEdit = %NameEdit
@onready var _panel: Control = $Center/Panel
@onready var _backdrop: TextureRect = %Backdrop
var compendium: Compendium = null
var updater: Updater = null
@onready var _update_row: Control = %UpdateRow
@onready var _update_label: Label = %UpdateLabel
@onready var _update_button: Button = %UpdateButton
@onready var _page_button: Button = %PageButton
var checklist: PlaytestChecklist = null
var records: RecordsScreen = null


func _ready() -> void:
	# The Crypt's floor, dimmed, as a backdrop (same baker as the arena).
	var floor_image := FloorBaker.bake(Stages.get_stage(1), Vector2i(640, 360), 2024)
	_backdrop.texture = ImageTexture.create_from_image(floor_image)
	_port_edit.text = str(Net.DEFAULT_PORT)
	_version_label.text = BuildInfo.describe()
	_solo_button.pressed.connect(func() -> void: solo_requested.emit())
	_host_button.pressed.connect(func() -> void: host_requested.emit(_port()))
	_join_button.pressed.connect(_on_join_pressed)
	_settings_button.pressed.connect(open_settings)
	_exit_button.pressed.connect(func() -> void: get_tree().quit())
	_name_edit.max_length = PlayerNames.MAX_LENGTH
	_name_edit.text = PlayerNames.sanitize(Settings.player_name)
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _solo_button.grab_focus())
	_feedback_button.pressed.connect(func() -> void:
		_panel.hide()
		feedback_requested.emit())
	_settings.closed.connect(func() -> void:
		_panel.show()
		_settings_button.grab_focus())
	compendium = Compendium.new()
	checklist = PlaytestChecklist.new()
	records = RecordsScreen.new()
	for page: Array in [[compendium, _compendium_button], [records, _records_button], [checklist, _checklist_button]]:
		var screen: ListScreen = page[0]
		var button: Button = page[1]
		add_child(screen)
		button.pressed.connect(func() -> void:
			_panel.hide()
			_version_label.hide()
			screen.open())
		screen.closed.connect(func() -> void:
			_panel.show()
			_version_label.show()
			button.grab_focus())
	_address_edit.text_submitted.connect(func(_text: String) -> void: _on_join_pressed())
	updater = Updater.new()
	add_child(updater)
	updater.changed.connect(_refresh_update)
	_update_button.pressed.connect(updater.update)
	_page_button.pressed.connect(updater.open_release_page)
	_refresh_update()


## Saved as you type (the feedback screen uses the same name).
func _on_name_changed(text: String) -> void:
	Settings.player_name = PlayerNames.sanitize(text)
	Settings.save()


## The update line under the menu buttons, from the updater's state.
func _refresh_update() -> void:
	var latest := updater.latest.version if updater.latest != null else "?"
	var text := ""
	var color := Color(0.55, 0.9, 0.45)
	_update_button.visible = false
	_page_button.visible = false
	match updater.state:
		Updater.State.AVAILABLE:
			text = "Version %s is out!" % latest
			_update_button.text = "Update now"
			_update_button.visible = true
		Updater.State.DOWNLOADING:
			text = "Downloading %s... %d%%" % [latest, roundi(updater.progress() * 100.0)]
		Updater.State.INSTALLING:
			text = "Installing... the game will restart."
		Updater.State.FAILED:
			text = updater.error
			color = Color(0.95, 0.5, 0.45)
			_update_button.text = "Try again"
			_update_button.visible = true
			_page_button.visible = true
	_update_label.text = text
	_update_label.add_theme_color_override("font_color", color)
	_update_row.visible = not text.is_empty()
	var suffix := ""
	if updater.state == Updater.State.UP_TO_DATE:
		suffix = "   (latest version)"
	elif updater.state == Updater.State.CHECKING:
		suffix = "   checking for updates..."
	_version_label.text = BuildInfo.describe() + suffix
	# No starting a game mid-update (re-enabled if the update fails).
	if updater.state == Updater.State.DOWNLOADING or updater.state == Updater.State.INSTALLING:
		_set_buttons_enabled(false)
	elif updater.state == Updater.State.FAILED:
		_set_buttons_enabled(true)


func show_menu(message: String = "") -> void:
	show()
	_panel.show()
	_name_edit.text = PlayerNames.sanitize(Settings.player_name)  # The feedback screen can change it too.
	_settings.hide()
	compendium.hide()
	checklist.hide()
	records.hide()
	_status_label.text = message
	_set_buttons_enabled(true)
	_solo_button.grab_focus()


## Back from the feedback screen.
func show_panel_after_feedback() -> void:
	_panel.show()
	_feedback_button.grab_focus()


func open_settings() -> void:
	_panel.hide()
	_settings.open()


## Shows the menu with buttons disabled while something is in progress.
func show_busy(message: String) -> void:
	show()
	_status_label.text = message
	_set_buttons_enabled(false)


func _on_join_pressed() -> void:
	var invite: Dictionary = Net.parse_invite(_address_edit.text, Net.DEFAULT_PORT)
	var address: String = invite["address"]
	if address.is_empty():
		_status_label.text = "Paste the invite your host sent you (looks like 203.0.113.5:7777)."
		return
	join_requested.emit(address, invite["port"])


func _port() -> int:
	var port := _port_edit.text.to_int()
	if port <= 0 or port > 65535:
		return Net.DEFAULT_PORT
	return port


func _set_buttons_enabled(enabled: bool) -> void:
	for button: Button in [_solo_button, _host_button, _join_button]:
		button.disabled = not enabled
