class_name FlowField
extends RefCounted
## Breadth-first distance field from a set of goal cells, shared by every
## creature heading for the same target. Moving = stepping to the neighbour
## with the lowest distance (diagonals only when both orthogonals are free,
## like the A* grid). Built by Pathfinder.flow_to, cached per target and
## dropped when Pathfinder.version changes.

const DX: Array[int] = [1, -1, 0, 0, 1, 1, -1, -1]
const DY: Array[int] = [0, 0, 1, -1, 1, -1, 1, -1]

var w := 0
var h := 0
var version := 0
## Steps to the nearest goal; -1 when unreached (or beyond max_dist).
var dist := PackedInt32Array()
## True once the search has exhausted its frontier (otherwise `dist` is final only where >= 0).
var complete := false
var _walk := PackedByteArray()
var _queue := PackedInt32Array()
var _head := 0
var _max_dist := -1


## Starts a search; `budget` < 0 finishes it now, otherwise `expand` continues it later.
func build(walk: PackedByteArray, p_w: int, p_h: int, sources: Array[Vector2i], max_dist := -1, budget := -1) -> void:
	w = p_w
	h = p_h
	_walk = walk
	_max_dist = max_dist
	dist.resize(w * h)
	dist.fill(-1)
	for s in sources:
		if s.x < 0 or s.y < 0 or s.x >= w or s.y >= h:
			continue
		var i := s.y * w + s.x
		if dist[i] == -1 and walk[i] != 0:
			dist[i] = 0
			_queue.append(i)
	complete = false
	expand(budget)


## Expands up to `budget` cells (all when < 0).
func expand(budget: int) -> void:
	if complete:
		return
	var walk := _walk
	var done := 0
	while _head < _queue.size():
		if budget >= 0 and done >= budget:
			return
		done += 1
		var i := _queue[_head]
		_head += 1
		var d := dist[i] + 1
		if _max_dist >= 0 and d > _max_dist:
			continue
		var cx := i % w
		var cy := i / w
		for k in 8:
			var nx := cx + DX[k]
			var ny := cy + DY[k]
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var ni := ny * w + nx
			if dist[ni] != -1 or walk[ni] == 0:
				continue
			if k >= 4 and (walk[cy * w + nx] == 0 or walk[ny * w + cx] == 0):
				continue
			dist[ni] = d
			_queue.append(ni)
	complete = true
	_queue = PackedInt32Array()


func dist_at(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return -1
	return dist[c.y * w + c.x]


## Best neighbour of `c` (strictly closer to the goal), or (-1, -1) when `c`
## is unreached, already at a goal, or boxed in.
func next_step(c: Vector2i, walk: PackedByteArray) -> Vector2i:
	var cur := dist_at(c)
	if cur <= 0:
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_d := cur
	for k in 8:
		var nx := c.x + DX[k]
		var ny := c.y + DY[k]
		if nx < 0 or ny < 0 or nx >= w or ny >= h:
			continue
		var d := dist[ny * w + nx]
		if d < 0 or d >= best_d:
			continue
		if k >= 4 and (walk[c.y * w + nx] == 0 or walk[ny * w + c.x] == 0):
			continue
		best_d = d
		best = Vector2i(nx, ny)
	return best
