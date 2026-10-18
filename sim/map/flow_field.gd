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
## Window of the map covered by `dist` (the whole map for unbounded fields; the sources'
## bounding box grown by max_dist for bounded ones - nothing outside it can be reached).
var x0 := 0
var y0 := 0
var ww := 0
var wh := 0
## Last-use stamp for the Pathfinder's LRU eviction.
var last_use := 0
## Steps to the nearest goal inside the window (row-major, ww x wh); -1 when unreached (or beyond max_dist).
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
	x0 = 0
	y0 = 0
	ww = w
	wh = h
	if max_dist >= 0 and not sources.is_empty():
		var lx := w
		var ly := h
		var hx := -1
		var hy := -1
		for s in sources:
			if s.x < 0 or s.y < 0 or s.x >= w or s.y >= h:
				continue
			lx = mini(lx, s.x)
			ly = mini(ly, s.y)
			hx = maxi(hx, s.x)
			hy = maxi(hy, s.y)
		if hx >= 0:
			x0 = maxi(0, lx - max_dist)
			y0 = maxi(0, ly - max_dist)
			ww = mini(w - 1, hx + max_dist) - x0 + 1
			wh = mini(h - 1, hy + max_dist) - y0 + 1
		else:
			ww = 0
			wh = 0
	dist.resize(ww * wh)
	dist.fill(-1)
	for s in sources:
		if s.x < x0 or s.y < y0 or s.x >= x0 + ww or s.y >= y0 + wh:
			continue
		if dist[(s.y - y0) * ww + s.x - x0] == -1 and walk[s.y * w + s.x] != 0:
			dist[(s.y - y0) * ww + s.x - x0] = 0
			_queue.append(s.y * w + s.x)
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
		var cx := i % w
		var cy := i / w
		var d := dist[(cy - y0) * ww + cx - x0] + 1
		if _max_dist >= 0 and d > _max_dist:
			continue
		for k in 8:
			var nx := cx + DX[k]
			var ny := cy + DY[k]
			if nx < x0 or ny < y0 or nx >= x0 + ww or ny >= y0 + wh:
				continue
			var ni := ny * w + nx
			var di := (ny - y0) * ww + nx - x0
			if dist[di] != -1 or walk[ni] == 0:
				continue
			if k >= 4 and (walk[cy * w + nx] == 0 or walk[ny * w + cx] == 0):
				continue
			dist[di] = d
			_queue.append(ni)
	complete = true
	_queue = PackedInt32Array()


func dist_at(c: Vector2i) -> int:
	if c.x < x0 or c.y < y0 or c.x >= x0 + ww or c.y >= y0 + wh:
		return -1
	return dist[(c.y - y0) * ww + c.x - x0]


## True when a walkability change at `c` can alter this field.
func touches(c: Vector2i) -> bool:
	if ww == 0:
		return true  # sourceless: any change may give it sources
	return c.x >= x0 and c.y >= y0 and c.x < x0 + ww and c.y < y0 + wh


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
		if nx < x0 or ny < y0 or nx >= x0 + ww or ny >= y0 + wh:
			continue
		var d := dist[(ny - y0) * ww + nx - x0]
		if d < 0 or d >= best_d:
			continue
		if k >= 4 and (walk[c.y * w + nx] == 0 or walk[ny * w + c.x] == 0):
			continue
		best_d = d
		best = Vector2i(nx, ny)
	return best
