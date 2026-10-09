class_name LaunchOptions
extends RefCounted
## Optional command-line flags for quick testing without clicking through menus.
## Pass them after a lone `--` so Godot hands them to the game:
##   godot --path . -- --host --autopilot
##
##   --solo | --host | --join=<ip[:port]>   start immediately in that mode
##   --port=<n>                      port to host on / connect to (default 7777)
##   --autopilot                     the local player moves, aims and fires by itself
##   --run-for=<seconds>             print a report and quit (for headless smoke tests)
##   --local-only                    host without touching the router or looking up the public IP

enum Mode { MENU, SOLO, HOST, JOIN }

const NetScript: GDScript = preload("res://src/autoload/net.gd")

static var mode: Mode = Mode.MENU
static var address: String = "127.0.0.1"
static var port: int = NetScript.DEFAULT_PORT
static var autopilot: bool = false
static var run_for_seconds: float = 0.0
static var local_only: bool = false


static func parse(args: PackedStringArray) -> void:
	for arg: String in args:
		if arg == "--solo":
			mode = Mode.SOLO
		elif arg == "--host":
			mode = Mode.HOST
		elif arg.begins_with("--join="):
			mode = Mode.JOIN
			address = arg.trim_prefix("--join=")
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
		elif arg == "--autopilot":
			autopilot = true
		elif arg.begins_with("--run-for="):
			run_for_seconds = arg.trim_prefix("--run-for=").to_float()
		elif arg == "--local-only":
			local_only = true
		else:
			push_warning("Unknown launch option: %s" % arg)
