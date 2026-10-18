class_name BeltGrid
extends RefCounted
## Dense belt storage: one item per belt cell, deterministic stepping.
## Cells are indexed y * width + x (level 0 only for now; `level` params are
## reserved and must be 0). Dir: 0=N(0,-1) 1=E 2=S(0,1) 3=W; 255 = no belt.

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var width: int
var height: int
var ticks_per_cell: int
var dir: PackedByteArray
var item: PackedInt32Array  # -1 empty
var progress: PackedInt32Array
## Conservation counters: inserted == extracted + destroyed + item_count.
var inserted := 0
var extracted := 0
var destroyed := 0
var belt_count := 0
var item_count := 0

var _memo: PackedByteArray
var _claim: PackedInt32Array


func _init(w: int, h: int, p_ticks_per_cell: int = 5) -> void:
	width = w
	height = h
	ticks_per_cell = maxi(1, p_ticks_per_cell)
	var n := w * h
	dir = PackedByteArray()
	dir.resize(n)
	dir.fill(255)
	item = PackedInt32Array()
	item.resize(n)
	item.fill(-1)
	progress = PackedInt32Array()
	progress.resize(n)
	_memo = PackedByteArray()
	_memo.resize(n)
	_claim = PackedInt32Array()
	_claim.resize(n)


func index(c: Vector2i, level: int = 0) -> int:
	assert(level == 0)
	return c.y * width + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func has_belt(c: Vector2i, level: int = 0) -> bool:
	return in_bounds(c) and dir[index(c, level)] != 255


func belt_dir(c: Vector2i, level: int = 0) -> int:
	if not has_belt(c, level):
		return -1
	return dir[index(c, level)]


func item_at(c: Vector2i, level: int = 0) -> int:
	if not in_bounds(c):
		return -1
	return item[index(c, level)]


## Place a belt or rotate an existing one. False when out of bounds / bad dir.
func set_belt(c: Vector2i, d: int, level: int = 0) -> bool:
	if not in_bounds(c) or d < 0 or d > 3:
		return false
	var i := index(c, level)
	if dir[i] == 255:
		belt_count += 1
	dir[i] = d
	return true


## Remove a belt; returns the item id it carried (-1 none), counted as destroyed.
func remove_belt(c: Vector2i, level: int = 0) -> int:
	if not has_belt(c, level):
		return -1
	var i := index(c, level)
	var it := item[i]
	if it >= 0:
		destroyed += 1
		item_count -= 1
	item[i] = -1
	progress[i] = 0
	dir[i] = 255
	belt_count -= 1
	return it


## Put an item on an empty belt cell (port output). False if occupied/no belt.
func insert(c: Vector2i, item_id: int, level: int = 0) -> bool:
	if not has_belt(c, level):
		return false
	var i := index(c, level)
	if item[i] >= 0:
		return false
	item[i] = item_id
	progress[i] = 0
	inserted += 1
	item_count += 1
	return true


## Item that reached the far edge of this cell, or -1.
func peek_ready(c: Vector2i, level: int = 0) -> int:
	if not has_belt(c, level):
		return -1
	var i := index(c, level)
	if item[i] >= 0 and progress[i] >= ticks_per_cell:
		return item[i]
	return -1


## Take the ready item (port input / sink). -1 if none is ready.
func take_ready(c: Vector2i, level: int = 0) -> int:
	var it := peek_ready(c, level)
	if it < 0:
		return -1
	var i := index(c, level)
	item[i] = -1
	progress[i] = 0
	extracted += 1
	item_count -= 1
	return it


func _target(i: int) -> int:
	var d := dir[i]
	var x := i % width + DIRS[d].x
	var y := i / width + DIRS[d].y
	if x < 0 or y < 0 or x >= width or y >= height:
		return -1
	var t := y * width + x
	var td := dir[t]
	if td == 255 or (td + 2) % 4 == d:  # no belt, or head-on
		return -1
	return t


## memo: 0 unknown, 1 visiting, 2 moves, 3 stays. Cycles stall (legal).
func _resolve(i: int) -> bool:
	var m := _memo[i]
	if m == 2:
		return true
	if m >= 1:
		return false
	_memo[i] = 1
	var ok := false
	if item[i] >= 0 and progress[i] >= ticks_per_cell:
		var t := _target(i)
		if t >= 0 and _claim[t] == 0 and (item[t] < 0 or _resolve(t)):
			if _claim[t] == 0:
				_claim[t] = i + 1
				ok = true
	_memo[i] = 2 if ok else 3
	return ok


func step() -> void:
	if item_count == 0:
		return
	var n := width * height
	for i in n:
		if item[i] >= 0 and progress[i] < ticks_per_cell:
			progress[i] += 1
	_memo.fill(0)
	_claim.fill(0)
	var movers := PackedInt32Array()
	for i in n:
		if item[i] >= 0 and _resolve(i):
			movers.append(i)
	var carried := PackedInt32Array()
	var targets := PackedInt32Array()
	for i in movers:
		carried.append(item[i])
		targets.append(_target(i))
		item[i] = -1
		progress[i] = 0
	for k in movers.size():
		item[targets[k]] = carried[k]
		progress[targets[k]] = 0


func state_hash() -> int:
	var h := 17
	for i in width * height:
		if dir[i] != 255:
			h = (h * 31 + i * 7 + dir[i]) & 0x7fffffff
			h = (h * 31 + item[i] + 1) & 0x7fffffff
			h = (h * 31 + progress[i]) & 0x7fffffff
	return h
