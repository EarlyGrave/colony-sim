class_name Pathfinder
extends RefCounted
## Grid pathfinding (AStarGrid2D) plus connected-component labels for cheap
## reachability checks. Keeps itself in sync with MapGrid via `refresh_cell`.

var map: MapGrid
var astar := AStarGrid2D.new()
var _component := PackedInt32Array()
var _components_dirty := true
# region perf-threat
## Bumped whenever a cell's walkability changes; invalidates flow fields.
var version := 0
## A* searches run (colonists, fallbacks). Creatures in steady state add none.
var astar_calls := 0
var flow_builds := 0
var _walk := PackedByteArray()
var _flows: Dictionary = {}
var _flows_version := -1
var _pending: Array[FlowField] = []
const MAX_CACHED_FLOWS := 48
# endregion
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
	_walk.resize(map.width * map.height)  # region perf-threat
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			var ok := is_walkable(c)
			astar.set_point_solid(c, not ok)
			_walk[y * map.width + x] = 1 if ok else 0  # region perf-threat
	_components_dirty = true
	version += 1  # region perf-threat


func refresh_cell(c: Vector2i) -> void:
	var ok := is_walkable(c)
	astar.set_point_solid(c, not ok)
	_components_dirty = true
	# region perf-threat
	var i := c.y * map.width + c.x
	if map.in_bounds(c) and _walk[i] != (1 if ok else 0):
		_walk[i] = 1 if ok else 0
		version += 1
	# endregion


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
	astar_calls += 1  # region perf-threat
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
	var w := map.width
	var h := map.height
	comp.resize(w * h)
	comp.fill(-1)
	# region perf-threat: flat-index flood fill (no Vector2i / Dictionary per cell)
	var next_id := 0
	var queue := PackedInt32Array()
	for i in comp.size():
		if comp[i] != -1 or not _label_ok(i, with_blocks):
			continue
		queue.clear()
		queue.append(i)
		comp[i] = next_id
		var head := 0
		while head < queue.size():
			var c := queue[head]
			head += 1
			var x := c % w
			var y := c / w
			if x + 1 < w and comp[c + 1] == -1 and _label_ok(c + 1, with_blocks):
				comp[c + 1] = next_id
				queue.append(c + 1)
			if x > 0 and comp[c - 1] == -1 and _label_ok(c - 1, with_blocks):
				comp[c - 1] = next_id
				queue.append(c - 1)
			if y + 1 < h and comp[c + w] == -1 and _label_ok(c + w, with_blocks):
				comp[c + w] = next_id
				queue.append(c + w)
			if y > 0 and comp[c - w] == -1 and _label_ok(c - w, with_blocks):
				comp[c - w] = next_id
				queue.append(c - w)
		next_id += 1
	# endregion


func _label_ok(i: int, with_blocks: bool) -> bool:
	return _walk[i] != 0 if with_blocks else map.tiles[i] == MapGrid.Tile.GROUND


# region perf-threat
## Walkability bytes (1 = walkable), row-major, for FlowField.
func walk_grid() -> PackedByteArray:
	return _walk


## Cached field under `key`, or null (also when the map changed since it was built).
func flow_cached(key: int) -> FlowField:
	if _flows_version != version:
		_flows.clear()
		_pending.clear()
		_flows_version = version
	return _flows.get(key)


## New field to `sources` stored under `key`. `max_dist` >= 0 bounds it and builds it at once;
## unbounded fields are built incrementally by `advance_flows` (creatures wait for the wavefront).
func flow_to(key: int, sources: Array[Vector2i], max_dist := -1) -> FlowField:
	var f := flow_cached(key)
	if f != null:
		return f
	if _flows.size() >= MAX_CACHED_FLOWS:
		_flows.clear()
		_pending.clear()
	f = FlowField.new()
	f.build(_walk, map.width, map.height, sources, max_dist, -1 if max_dist >= 0 else 0)
	_flows[key] = f
	if not f.complete:
		_pending.append(f)
	flow_builds += 1
	return f


## Spends `budget` cells of search on unfinished fields, oldest first.
func advance_flows(budget: int) -> void:
	while budget > 0 and not _pending.is_empty():
		var f: FlowField = _pending[0]
		var before := f._head
		f.expand(budget)
		budget -= maxi(1, f._head - before)
		if f.complete:
			_pending.pop_front()
		else:
			return


## Walkable goal cells for reaching `c`: the cell itself, or its walkable neighbours when solid.
func approach_cells(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if is_walkable(c):
		out.append(c)
		return out
	for d in MapGrid.NEIGHBORS_4:
		if is_walkable(c + d):
			out.append(c + d)
	return out
# endregion
