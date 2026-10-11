class_name HostInvite
extends Node
## Makes a hosted game reachable from the internet and builds the invite address
## (public IP:port) that friends paste into Join.
##
## Two independent background jobs start when hosting begins:
## 1. Public IP lookup: asks a tiny web service what our internet address is.
## 2. UPnP: asks the router to forward our UDP port to this PC automatically.
##    Many routers have UPnP turned off. Then the host must forward the port
##    once by hand in the router settings, and `status` says exactly what to forward.

signal changed

const PUBLIC_IP_URL: String = "https://api.ipify.org"
const UPNP_DISCOVER_TIMEOUT_MS: int = 2000
const MAPPING_DESCRIPTION: String = "Medieval Survival"

## "203.0.113.5:7777" once known, else empty.
var address: String = ""
## One line for the host's HUD about whether the router port is open.
var status: String = ""

var _port: int = 0
var _upnp: UPNP = null
## Counts start() / stop() calls, so a UPnP answer from an earlier session is
## recognised (it comes back on a background thread, maybe after leaving).
var _session: int = 0
## UPnP threads still running, by the session that started them.
var _upnp_threads: Dictionary[int, Thread] = {}
var _ip_request: HTTPRequest = null
## True between start() and stop().
var _hosting: bool = false


func start(port: int) -> void:
	stop()
	_port = port
	_hosting = true
	_set_status("Router: checking for automatic port forwarding...")
	_ip_request = HTTPRequest.new()
	_ip_request.timeout = 5.0
	add_child(_ip_request)
	_ip_request.request_completed.connect(_on_public_ip_response)
	_ip_request.request(PUBLIC_IP_URL)
	_session += 1
	var thread := Thread.new()
	_upnp_threads[_session] = thread
	thread.start(_open_port_with_upnp.bind(port, _session))


## Closes the router port (if we opened it) and forgets the invite. Doesn't wait
## for a UPnP search still running: its answer is dropped (and its port closed)
## when it arrives.
func stop() -> void:
	_session += 1
	_hosting = false
	if _upnp != null:
		_upnp.delete_port_mapping(_port, "UDP")
		_upnp = null
	if _ip_request != null:
		_ip_request.queue_free()
		_ip_request = null
	address = ""
	status = ""


## Copies the invite to the clipboard. Returns false if there's nothing to copy yet.
func copy_to_clipboard() -> bool:
	if address.is_empty() or DisplayServer.get_name() == "headless":
		return false
	DisplayServer.clipboard_set(address)
	return true


func _exit_tree() -> void:
	stop()
	# Quitting: wait for any search still running and close what it opened.
	for session: int in _upnp_threads.keys():
		_close_stale(_upnp_threads[session].wait_to_finish())
	_upnp_threads.clear()


func _on_public_ip_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var ip := body.get_string_from_utf8().strip_edges()
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and ip.is_valid_ip_address():
		_set_address(ip)
	elif address.is_empty():
		push_warning("Could not look up public IP (result %d, HTTP %d)." % [result, response_code])
	_ip_request.queue_free()
	_ip_request = null


## Runs on a background thread: UPnP discovery can take a couple of seconds.
## Returns [UPNP or null, external IP, port]; the main thread collects it in
## _on_upnp_finished.
func _open_port_with_upnp(port: int, session: int) -> Array:
	var upnp := UPNP.new()
	var opened := false
	var external_ip := ""
	if upnp.discover(UPNP_DISCOVER_TIMEOUT_MS, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS \
			and upnp.get_device_count() > 0 and upnp.get_gateway().is_valid_gateway():
		opened = upnp.add_port_mapping(port, port, MAPPING_DESCRIPTION, "UDP", 0) == UPNP.UPNP_RESULT_SUCCESS
		external_ip = upnp.query_external_address()
	_on_upnp_finished.call_deferred(session)
	return [upnp if opened else null, external_ip, port]


func _on_upnp_finished(session: int) -> void:
	var thread: Thread = _upnp_threads.get(session)
	if thread == null:
		return
	_upnp_threads.erase(session)
	var result: Array = thread.wait_to_finish()
	if session != _session:
		_close_stale(result)  # We stopped hosting (or started again) meanwhile.
		return
	var upnp: UPNP = result[0]
	var external_ip: String = result[1]
	_upnp = upnp
	if upnp != null:
		_set_status("Router: port %d opened automatically (UPnP)." % _port)
	else:
		_set_status("Router: couldn't open the port automatically. Forward UDP %d to %s in your router." % [_port, local_ip()])
	if address.is_empty() and external_ip.is_valid_ip_address():
		_set_address(external_ip)


## A finished search from a session that's over: close the port it opened
## (unless we're hosting on that port again: the mapping is ours now).
func _close_stale(result: Variant) -> void:
	if not (result is Array) or (result as Array).size() != 3 or not (result[0] is UPNP):
		return
	var port: int = result[2]
	if not (_hosting and port == _port):
		(result[0] as UPNP).delete_port_mapping(port, "UDP")


func _set_address(ip: String) -> void:
	address = "%s:%d" % [ip, _port]
	copy_to_clipboard()
	changed.emit()


func _set_status(text: String) -> void:
	status = text
	changed.emit()


## This PC's address on the home network (what the router forwards to).
## Skips virtual adapters (WSL, Hyper-V, VPNs...) and prefers the usual
## home-router ranges: 192.168.x.x, then 10.x.x.x, then 172.16-31.x.x.
static func local_ip() -> String:
	var candidates: Array[String] = []
	for interface: Dictionary in IP.get_local_interfaces():
		var label := (str(interface.get("friendly", "")) + " " + str(interface.get("name", ""))).to_lower()
		if VIRTUAL_ADAPTER_HINTS.any(func(hint: String) -> bool: return label.contains(hint)):
			continue
		for ip: String in interface.get("addresses", []):
			candidates.append(ip)
	for prefix_rank: int in 3:
		for ip: String in candidates:
			if _private_ip_rank(ip) == prefix_rank:
				return ip
	return "this PC"


const VIRTUAL_ADAPTER_HINTS: Array[String] = ["vethernet", "wsl", "hyper-v", "virtualbox", "vmware", "tailscale", "zerotier", "hamachi", "loopback", "vpn"]


## 0 = 192.168.x.x, 1 = 10.x.x.x, 2 = 172.16-31.x.x, -1 = not a private IPv4 address.
static func _private_ip_rank(ip: String) -> int:
	if ip.begins_with("192.168."):
		return 0
	if ip.begins_with("10."):
		return 1
	var second := ip.get_slice(".", 1).to_int()
	if ip.begins_with("172.") and second >= 16 and second <= 31:
		return 2
	return -1
