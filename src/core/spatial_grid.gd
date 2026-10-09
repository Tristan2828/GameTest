class_name SpatialGrid
extends RefCounted
## Answers "which things are near this point?" quickly by sorting ids into square
## cells. Instead of checking all 300 enemies, a query only looks at the few cells
## around the point. Rebuild it each tick: clear(), then insert() everything.

var cell_size: float = 32.0

var _cells: Dictionary[Vector2i, Array] = {}


func _init(size: float = 32.0) -> void:
	cell_size = size


func clear() -> void:
	_cells.clear()


func insert(id: int, point: Vector2) -> void:
	var key := _cell_of(point)
	if not _cells.has(key):
		_cells[key] = []
	_cells[key].append(id)


## Appends to `out` every id whose cell overlaps the circle. Callers still need
## an exact distance check; this only narrows down the candidates.
func query(point: Vector2, radius: float, out: Array[int]) -> void:
	var low := _cell_of(point - Vector2(radius, radius))
	var high := _cell_of(point + Vector2(radius, radius))
	for x: int in range(low.x, high.x + 1):
		for y: int in range(low.y, high.y + 1):
			var cell: Array = _cells.get(Vector2i(x, y), [])
			for id: int in cell:
				out.append(id)


func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
