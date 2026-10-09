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


func _ready() -> void:
	_port_edit.text = str(Net.DEFAULT_PORT)
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "dev")
	_solo_button.pressed.connect(func() -> void: solo_requested.emit())
	_host_button.pressed.connect(func() -> void: host_requested.emit(_port()))
	_join_button.pressed.connect(_on_join_pressed)


func show_menu(message: String = "") -> void:
	show()
	_status_label.text = message
	_set_buttons_enabled(true)
	_solo_button.grab_focus()


## Shows the menu with buttons disabled while something is in progress.
func show_busy(message: String) -> void:
	show()
	_status_label.text = message
	_set_buttons_enabled(false)


func _on_join_pressed() -> void:
	var address := _address_edit.text.strip_edges()
	if address.is_empty():
		_status_label.text = "Enter the host's IP address."
		return
	join_requested.emit(address, _port())


func _port() -> int:
	var port := _port_edit.text.to_int()
	if port <= 0 or port > 65535:
		return Net.DEFAULT_PORT
	return port


func _set_buttons_enabled(enabled: bool) -> void:
	for button: Button in [_solo_button, _host_button, _join_button]:
		button.disabled = not enabled
