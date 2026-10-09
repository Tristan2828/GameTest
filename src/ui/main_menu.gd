class_name MainMenu
extends CanvasLayer
## Title menu: play solo, host a game, or join a host by IP address. Also opens
## Settings, the Compendium (info on heroes, weapons, items, enemies) and the
## Playtest Checklist (what still needs testing, from docs/PLAYTEST.md).
## In the exported game it also checks GitHub for a newer version and offers an
## Update button (see Updater).

signal solo_requested
signal host_requested(port: int)
signal join_requested(address: String, port: int)

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
@onready var _panel: Control = $Center/Panel
@onready var _backdrop: TextureRect = %Backdrop
var compendium: Compendium = null
var updater: Updater = null
@onready var _update_row: Control = %UpdateRow
@onready var _update_label: Label = %UpdateLabel
@onready var _update_button: Button = %UpdateButton
@onready var _page_button: Button = %PageButton
var checklist: PlaytestChecklist = null


func _ready() -> void:
	# The Crypt's floor, dimmed, as a backdrop (same baker as the arena).
	var floor_image := FloorBaker.bake(Stages.get_stage(1), Vector2i(640, 360), 2024)
	_backdrop.texture = ImageTexture.create_from_image(floor_image)
	_port_edit.text = str(Net.DEFAULT_PORT)
	_version_label.text = BuildInfo.describe()
	_solo_button.pressed.connect(func() -> void: solo_requested.emit())
	_host_button.pressed.connect(func() -> void: host_requested.emit(_port()))
	_join_button.pressed.connect(_on_join_pressed)
	_settings_button.pressed.connect(func() -> void:
		_panel.hide()
		_settings.open())
	_settings.closed.connect(func() -> void:
		_panel.show()
		_settings_button.grab_focus())
	compendium = Compendium.new()
	checklist = PlaytestChecklist.new()
	for page: Array in [[compendium, _compendium_button], [checklist, _checklist_button]]:
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
	_settings.hide()
	compendium.hide()
	checklist.hide()
	_status_label.text = message
	_set_buttons_enabled(true)
	_solo_button.grab_focus()


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
