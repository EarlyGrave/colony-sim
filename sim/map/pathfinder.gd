class_name Pathfinder
extends RefCounted
## Grid pathfinding (AStarGrid2D) plus connected-component labels for cheap
## reachability checks. Keeps itself in sync with MapGrid via `refresh_cell`.

var map: MapGrid
var astar := AStarGrid2D.new()
var _component := PackedInt32Array()
var _components_dirty := true
# region construction
## Cells made solid by buildings (walls): Vector2i -> true. MapGrid stays terrain-only.
var blocked: Dictionary = {}
## Component labels of the bare terrain (walls ignored), for spawn decisions.
var _terrain_component := PackedInt32Array()
# endregion


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
			astar.set_point_solid(c, not is_walkable(c))
	_components_dirty = true


func refresh_cell(c: Vector2i) -> void:
	astar.set_point_solid(c, not is_walkable(c))
	_components_dirty = true


# region construction
## Terrain passable and not covered by a solid building.
func is_walkable(c: Vector2i) -> bool:
	return map.is_passable(c) and not blocked.has(c)


func set_blocked(c: Vector2i, on: bool) -> void:
	if on == blocked.has(c):
		return
	if on:
		blocked[c] = true
	else:
		blocked.erase(c)
	refresh_cell(c)


## Reachability on bare terrain, ignoring walls (where could a creature come from).
func reachable_terrain(a: Vector2i, b: Vector2i) -> bool:
	if not map.is_passable(a) or not map.is_passable(b):
		return false
	_ensure_components()
	return _terrain_component[map.idx(a)] == _terrain_component[map.idx(b)]


## True if `from` can get to `cell` itself, or next to it when `cell` is solid.
func can_approach(from: Vector2i, cell: Vector2i) -> bool:
	if is_walkable(cell):
		return reachable(from, cell)
	return best_adjacent(from, cell).x >= 0
# endregion


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
		if is_walkable(n) and reachable(from, n):
			var dist := Vector2(n - from).length()
			if dist < best_d:
				best_d = dist
				best = n
	return best


func reachable(a: Vector2i, b: Vector2i) -> bool:
	if not is_walkable(a) or not is_walkable(b):
		return false
	_ensure_components()
	return _component[map.idx(a)] == _component[map.idx(b)]


func component_of(c: Vector2i) -> int:
	if not is_walkable(c):
		return -1
	_ensure_components()
	return _component[map.idx(c)]


func _ensure_components() -> void:
	if not _components_dirty:
		return
	_components_dirty = false
	_label(_component, true)
	_label(_terrain_component, false)


func _label(comp: PackedInt32Array, with_blocks: bool) -> void:
	comp.resize(map.width * map.height)
	comp.fill(-1)
	var next_id := 0
	for i in comp.size():
		var start := Vector2i(i % map.width, i / map.width)
		if comp[i] != -1 or map.tiles[i] != MapGrid.Tile.GROUND or (with_blocks and blocked.has(start)):
			continue
		var queue: Array[Vector2i] = [start]
		comp[i] = next_id
		var head := 0
		while head < queue.size():
			var c := queue[head]
			head += 1
			for d in MapGrid.NEIGHBORS_4:
				var n := c + d
				if map.is_passable(n) and comp[map.idx(n)] == -1 and not (with_blocks and blocked.has(n)):
					comp[map.idx(n)] = next_id
					queue.append(n)
		next_id += 1
