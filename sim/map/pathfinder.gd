class_name Pathfinder
extends RefCounted
## Grid pathfinding (AStarGrid2D) plus connected-component labels for cheap
## reachability checks. Keeps itself in sync with MapGrid via `refresh_cell`.

var map: MapGrid
var astar := AStarGrid2D.new()
var _component := PackedInt32Array()
var _components_dirty := true


func _init(p_map: MapGrid) -> void:
	map = p_map
	astar.region = Rect2i(0, 0, map.width, map.height)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	rebuild()


func rebuild() -> void:
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			astar.set_point_solid(c, not map.is_passable(c))
	_components_dirty = true


func refresh_cell(c: Vector2i) -> void:
	astar.set_point_solid(c, not map.is_passable(c))
	_components_dirty = true


## Path from `from` to `to`, excluding `from`. Empty if unreachable or same cell.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if from == to or not reachable(from, to):
		return out
	var p := astar.get_id_path(from, to)
	for i in range(1, p.size()):
		out.append(p[i])
	return out


## Shortest-path goal among passable cells next to `target` (4-neighborhood).
## Returns Vector2i(-1, -1) if none is reachable.
func best_adjacent(from: Vector2i, target: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for d in MapGrid.NEIGHBORS_4:
		var n := target + d
		if n == from:
			return n
		if map.is_passable(n) and reachable(from, n):
			var dist := Vector2(n - from).length()
			if dist < best_d:
				best_d = dist
				best = n
	return best


func reachable(a: Vector2i, b: Vector2i) -> bool:
	if not map.is_passable(a) or not map.is_passable(b):
		return false
	_ensure_components()
	return _component[map.idx(a)] == _component[map.idx(b)]


func component_of(c: Vector2i) -> int:
	if not map.is_passable(c):
		return -1
	_ensure_components()
	return _component[map.idx(c)]


func _ensure_components() -> void:
	if not _components_dirty:
		return
	_components_dirty = false
	_component.resize(map.width * map.height)
	_component.fill(-1)
	var next_id := 0
	for i in _component.size():
		if _component[i] != -1 or map.tiles[i] != MapGrid.Tile.GROUND:
			continue
		var queue: Array[Vector2i] = [Vector2i(i % map.width, i / map.width)]
		_component[i] = next_id
		var head := 0
		while head < queue.size():
			var c := queue[head]
			head += 1
			for d in MapGrid.NEIGHBORS_4:
				var n := c + d
				if map.is_passable(n) and _component[map.idx(n)] == -1:
					_component[map.idx(n)] = next_id
					queue.append(n)
		next_id += 1
