class_name ArenaFloor
extends Node2D
## The arena's ground. FloorBaker paints each stage's floor (ground, props,
## walls, candle light) into one image when the stage starts; this node just
## draws that texture. A fixed seed per stage means every player sees the same
## floor. Purely visual (no collision).

@export var bounds: Rect2 = Rect2(0, 0, 1600, 1000)
@export var seed_value: int = 1337

var _texture: ImageTexture = null


## Repaint the floor for a stage.
func apply_stage(stage: StageDef) -> void:
	var stage_seed := seed_value + maxi(Stages.ALL.find(stage), 0) * 7919
	_texture = ImageTexture.create_from_image(FloorBaker.bake(stage, Vector2i(bounds.size), stage_seed))
	queue_redraw()


func _draw() -> void:
	if _texture != null:
		draw_texture(_texture, bounds.position - Vector2(FloorBaker.WALL, FloorBaker.WALL))
