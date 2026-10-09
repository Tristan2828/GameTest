class_name StageDef
extends Resource
## Everything that makes a stage different: its enemies, its boss and the boss's
## attack script, and how the floor looks. One `.tres` per stage in
## `src/stages/`, registered in Stages.ALL (index = stage number - 1).

enum PropStyle { CRYPT, MARSH, CATHEDRAL }

@export var title: String = "Stage"
## Tracks name for this stage's music.
@export var music: StringName = &"crypt"

@export_group("Enemies")
@export var spawns: Array[SpawnEntry] = []
## Enemy type used for pack surges.
@export var pack_type: int = 0

@export_group("Boss")
@export var boss_type: int = 0
@export var boss_phase_one: Array[BossStep] = []
## Used below 50% HP.
@export var boss_phase_two: Array[BossStep] = []

@export_group("Floor")
@export var stone_colors: Array[Color] = []
@export var grout_color: Color = Color(0.065, 0.06, 0.08)
@export var crack_color: Color = Color(0.05, 0.045, 0.06)
@export var moss_color: Color = Color(0.13, 0.17, 0.11)
@export var wall_color: Color = Color(0.2, 0.17, 0.25)
@export var wall_edge_color: Color = Color(0.4, 0.33, 0.5)
@export var prop_style: PropStyle = PropStyle.CRYPT
