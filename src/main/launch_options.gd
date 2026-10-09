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
##   --stage-seconds=<n>             shorter/longer stage (default 300) for testing
##   --start-at=<seconds>            host starts the stage clock here (test late-stage content)
##   --character=<n>                 play this character (0 Wanderer, 1 Gravekeeper, 2 Witch); with
##                                   --autopilot a joining client picks it in the lobby
##   --start-stage=<n>               host starts the run at stage n (1-3)
##   --give-weapons                  every player starts with all auto weapons at level 2
##   --weak-bosses                   bosses have 2% HP (test stage transitions quickly)
##   --screenshot-dir=<folder>       save PNGs: the title screen (when no mode flag), gameplay every 10s,
##                                   and the first lobby, level-up, shop and run-end screens
##                                   (needs a real window, not --headless)
##   --perf-log                      print step timings, fps and object counts every second
##   --invincible                    players can't be hit (performance / visual testing)
##   --run-config=<k=v,k=v>          host's Difficulty / Custom Game settings (RunConfig names),
##                                   e.g. --run-config=single_stage=true,stage=2,enemy_health=1.5

enum Mode { MENU, SOLO, HOST, JOIN }

const NetScript: GDScript = preload("res://src/autoload/net.gd")

static var mode: Mode = Mode.MENU
static var address: String = "127.0.0.1"
static var port: int = NetScript.DEFAULT_PORT
static var autopilot: bool = false
static var run_for_seconds: float = 0.0
static var local_only: bool = false
static var stage_seconds: float = 0.0
static var screenshot_dir: String = ""
static var start_at_seconds: float = 0.0
static var weak_bosses: bool = false
static var give_weapons: bool = false
static var start_stage: int = 1
static var character: int = -1
## --run-config values (RunConfig names -> parsed values); empty = lobby choice.
static var run_config: Dictionary = {}
static var invincible: bool = false


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
		elif arg.begins_with("--character="):
			character = arg.trim_prefix("--character=").to_int()
		elif arg.begins_with("--start-stage="):
			start_stage = clampi(arg.trim_prefix("--start-stage=").to_int(), 1, 3)
		elif arg == "--give-weapons":
			give_weapons = true
		elif arg == "--weak-bosses":
			weak_bosses = true
		elif arg.begins_with("--start-at="):
			start_at_seconds = arg.trim_prefix("--start-at=").to_float()
		elif arg.begins_with("--screenshot-dir="):
			screenshot_dir = arg.trim_prefix("--screenshot-dir=")
		elif arg.begins_with("--stage-seconds="):
			stage_seconds = arg.trim_prefix("--stage-seconds=").to_float()
		elif arg == "--perf-log":
			PerfLog.enabled = true
		elif arg == "--invincible":
			invincible = true
		elif arg.begins_with("--run-config="):
			for pair: String in arg.trim_prefix("--run-config=").split(",", false):
				var parts := pair.split("=")
				if parts.size() == 2:
					var text := parts[1].strip_edges()
					run_config[parts[0].strip_edges()] = (text == "true") if text in ["true", "false"] else text.to_float()
		else:
			push_warning("Unknown launch option: %s" % arg)
