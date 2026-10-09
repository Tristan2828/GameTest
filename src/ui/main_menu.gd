class_name MainMenu
extends CanvasLayer
## Title menu: play solo, host a game, or join a host by IP address.

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
@onready var _panel: Control = $Center/Panel
@onready var _backdrop: TextureRect = %Backdrop


func _ready() -> void:
	# The Crypt's floor, dimmed, as a backdrop (same baker as the arena).
	var floor_image := FloorBaker.bake(Stages.get_stage(1), Vector2i(640, 360), 2024)
	_backdrop.texture = ImageTexture.create_from_image(floor_image)
	_port_edit.text = str(Net.DEFAULT_PORT)
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "dev")
	_solo_button.pressed.connect(func() -> void: solo_requested.emit())
	_host_button.pressed.connect(func() -> void: host_requested.emit(_port()))
	_join_button.pressed.connect(_on_join_pressed)
	_settings_button.pressed.connect(func() -> void:
		_panel.hide()
		_settings.open())
	_settings.closed.connect(func() -> void:
		_panel.show()
		_settings_button.grab_focus())
	_address_edit.text_submitted.connect(func(_text: String) -> void: _on_join_pressed())


func show_menu(message: String = "") -> void:
	show()
	_panel.show()
	_settings.hide()
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
