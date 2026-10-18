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
## Bumped on every place / remove / direction change (caches key on it, not on belt_count).
var version := 0
var item_count := 0

# region T3
const BITE_OFFSETS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Per-tile hit points (dense, 0 where no belt). Below `stall_hp` the tile stops moving.
var hp: PackedFloat32Array
var max_hp := 40.0
var stall_hp := 12.0
## Cells whose hp changed since the view last looked (cache only, not hashed).
var hp_dirty: Dictionary = {}
## Indices of damaged tiles (insertion ordered; for repair givers).
var hp_damaged: Dictionary = {}
## QA counters (not hashed): total hp bitten off belts, tiles repaired.
var hp_lost_total := 0.0
var repairs_total := 0
# endregion

var _memo: PackedByteArray
var _claim: PackedInt32Array
## Sparse stepping: indices that may hold an item (superset; stale entries are
## dropped in step()). `_in_occ` flags membership so each index appears once.
var _occ := PackedInt32Array()
var _in_occ: PackedByteArray


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
	_in_occ = PackedByteArray()
	_in_occ.resize(n)
	hp = PackedFloat32Array()  # region T3
	hp.resize(n)
	kind = PackedByteArray()  # region L1
	kind.resize(n)
	ptr = PackedByteArray()
	ptr.resize(n)
	_pick = PackedInt32Array()
	_pick.resize(n)


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
		hp[i] = max_hp  # region T3
	if dir[i] != d:
		version += 1
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
	hp[i] = 0.0  # region T3
	hp_damaged.erase(i)
	if kind[i] != 0:  # region L1
		_clear_node(i)
	belt_count -= 1
	version += 1
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
	_mark(i)
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


func _mark(i: int) -> void:
	if _in_occ[i] == 0:
		_in_occ[i] = 1
		_occ.append(i)


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
	if item[i] < 0 or progress[i] < ticks_per_cell:
		return false  # stable answer, no memo write needed
	_memo[i] = 1
	var ok := false
	if hp[i] >= stall_hp:  # region T3: damaged tile stalls
		if kind[i] >= 1 and kind[i] <= 3:  # region L1: splitter picks its output
			var nt := _node_pick(i)
			if nt >= 0:
				_claim[nt] = i + 1
				_pick[i] = nt
				ok = true
		else:
			var t := _target(i)
			if t >= 0 and _claim[t] == 0 and (item[t] < 0 or _resolve(t)):
				if _claim[t] == 0 and (kind[t] != 4 or _merger_allows(t, i)):  # region L1
					_claim[t] = i + 1
					ok = true
	_memo[i] = 2 if ok else 3
	return ok


func step() -> void:
	if item_count == 0:
		return
	# Sorted occupied indices == the dense 0..n scan order of the old code.
	_occ.sort()
	var ready := PackedInt32Array()
	var tpc := ticks_per_cell
	var w := 0
	var cnt := _occ.size()
	for k in cnt:
		var i := _occ[k]
		if item[i] < 0:
			_in_occ[i] = 0
			continue
		_occ[w] = i
		w += 1
		var p := progress[i]
		if p < tpc:
			progress[i] = p + 1
			if p + 1 >= tpc:
				ready.append(i)
		else:
			ready.append(i)
	_occ.resize(w)
	var movers := PackedInt32Array()
	for i in ready:
		if _resolve(i):
			movers.append(i)
	var carried := PackedInt32Array()
	var targets := PackedInt32Array()
	for i in movers:
		carried.append(item[i])
		targets.append(_pick[i] if kind[i] >= 1 and kind[i] <= 3 else _target(i))  # region L1
		item[i] = -1
		progress[i] = 0
	for i in ready:  # memo is written only for ready cells
		_memo[i] = 0
	for k in movers.size():
		var t := targets[k]
		_claim[t] = 0
		item[t] = carried[k]
		progress[t] = 0
		_mark(t)


func state_hash() -> int:
	var h := _plain_hash()
	if node_count > 0:  # region L1: node state joins the hash only when nodes exist
		h = _node_hash(h)
	return h


func _plain_hash() -> int:
	var h := 17
	for i in width * height:
		if dir[i] != 255:
			h = (h * 31 + i * 7 + dir[i]) & 0x7fffffff
			h = (h * 31 + item[i] + 1) & 0x7fffffff
			h = (h * 31 + progress[i]) & 0x7fffffff
			if hp[i] != max_hp:  # region T3: undamaged belts hash as before
				h = (h * 31 + int(hp[i] * 100.0) + 1) & 0x7fffffff
	return h


# region T3
func hp_at(c: Vector2i) -> float:
	return hp[index(c)] if has_belt(c) else -1.0


func is_stalled(c: Vector2i) -> bool:
	return has_belt(c) and hp[index(c)] < stall_hp


func is_damaged(c: Vector2i) -> bool:
	return has_belt(c) and hp[index(c)] < max_hp


## Bite a belt tile; true if it was a belt. The tile stays (hp floor 0) as a broken marker.
func damage_belt(c: Vector2i, amount: float) -> bool:
	if not has_belt(c):
		return false
	var i := index(c)
	hp_lost_total += minf(amount, hp[i])
	hp[i] = maxf(0.0, hp[i] - amount)
	hp_dirty[i] = true
	hp_damaged[i] = true
	return true


func repair_belt(c: Vector2i) -> void:
	if has_belt(c):
		var i := index(c)
		hp[i] = max_hp
		repairs_total += 1
		hp_dirty[i] = true
		hp_damaged.erase(i)
# endregion


# region L1
## Belt node kinds (BeltGrid.kind, 0 = plain belt). 1x1 cells inside the belt grid.
const K_BASIC := 1
const K_SMART := 2
const K_PRIORITY := 3
const K_MERGER := 4
const F_ANY := -1
const F_OVERFLOW := -2

var kind: PackedByteArray
## Round-robin pointer per node cell (basic/smart: next slot 0..2; merger: next input 0..2).
var ptr: PackedByteArray
var node_count := 0
## Smart filters: cell index -> PackedStringArray(3) ("any"|"overflow"|item id), slots 0=left 1=front 2=right.
var filters: Dictionary = {}
## Optional name -> item int resolver (LogisticsSystem sets it); default parses ints.
var item_resolver := Callable()
var _fcode: Dictionary = {}  # cell index -> PackedInt32Array(3) resolved codes
var _pick: PackedInt32Array


## Make `c` a node of `kind_` (1..4) flowing `d`; an existing belt keeps its item. Resets pointer/filters.
func place_node(kind_: int, c: Vector2i, d: int) -> bool:
	if kind_ < 1 or kind_ > 4 or not in_bounds(c) or d < 0 or d > 3:
		return false
	set_belt(c, d)
	var i := index(c)
	if kind[i] == 0:
		node_count += 1
	elif kind[i] != kind_:
		filters.erase(i)
		_fcode.erase(i)
	kind[i] = kind_
	ptr[i] = 0
	version += 1
	return true


## Turn a node back into a plain belt (keeps item and direction).
func remove_node(c: Vector2i) -> bool:
	if not has_belt(c) or kind[index(c)] == 0:
		return false
	_clear_node(index(c))
	version += 1
	return true


func _clear_node(i: int) -> void:
	kind[i] = 0
	ptr[i] = 0
	node_count -= 1
	filters.erase(i)
	_fcode.erase(i)


func node_kind(c: Vector2i) -> int:
	return kind[index(c)] if has_belt(c) else 0


func get_filter(c: Vector2i, slot: int) -> String:
	var f = filters.get(index(c))
	return f[slot] if f != null and slot >= 0 and slot < 3 else "any"


## Smart nodes only. value: "any" | "overflow" | item id. False if invalid.
func set_filter(c: Vector2i, slot: int, value: String) -> bool:
	if not has_belt(c) or slot < 0 or slot > 2:
		return false
	var i := index(c)
	if kind[i] != K_SMART:
		return false
	var code := F_ANY
	if value == "overflow":
		code = F_OVERFLOW
	elif value != "any":
		code = int(item_resolver.call(value)) if item_resolver.is_valid() else (value.to_int() if value.is_valid_int() else -1)
		if code < 0:
			return false
	var f: PackedStringArray = filters.get(i, PackedStringArray(["any", "any", "any"]))
	var fc: PackedInt32Array = _fcode.get(i, PackedInt32Array([F_ANY, F_ANY, F_ANY]))
	if f[slot] == value:
		return true
	f[slot] = value
	fc[slot] = code
	filters[i] = f
	_fcode[i] = fc
	version += 1
	return true


## Output cell index for slot (0=left 1=front 2=right) of node i, or -1 if not a valid output.
func _out_cell(i: int, slot: int) -> int:
	var d := (dir[i] + 3 + slot) % 4
	var x := i % width + DIRS[d].x
	var y := i / width + DIRS[d].y
	if x < 0 or y < 0 or x >= width or y >= height:
		return -1
	var t := y * width + x
	var td := dir[t]
	if td == 255 or (td + 2) % 4 == d:
		return -1
	return t


func _out_free(t: int) -> bool:
	return _claim[t] == 0 and (item[t] < 0 or _resolve(t))


# region K4
## True when splitter c has exactly one valid output and it is cell t (so it contends for t like a belt).
func _splitter_only_feeds(c: int, t: int) -> bool:
	var only := -1
	for sl in 3:
		var o := _out_cell(c, sl)
		if o >= 0:
			if only >= 0:
				return false
			only = o
	return only == t


## Output free, and a merger output also lets this node take its turn in the rotation.
func _out_ok(t: int, from: int) -> bool:
	return _out_free(t) and (kind[t] != K_MERGER or _merger_allows(t, from))
# endregion


## Chosen output cell for the ready item in splitter i, or -1 (blocked). Advances the pointer on success.
func _node_pick(i: int) -> int:
	var k := kind[i]
	var outs := [-1, -1, -1]
	for s in 3:
		outs[s] = _out_cell(i, s)
	if k == K_PRIORITY:
		for s in [1, 0, 2]:
			if outs[s] >= 0 and _out_ok(outs[s], i):
				return outs[s]
		return -1
	var start := ptr[i]
	if k == K_BASIC:
		for n in 3:
			var s := (start + n) % 3
			if outs[s] >= 0 and _out_ok(outs[s], i):
				ptr[i] = (s + 1) % 3
				return outs[s]
		return -1
	# smart: explicit match, then any (round-robin), then overflow
	var fc: PackedInt32Array = _fcode.get(i, PackedInt32Array([F_ANY, F_ANY, F_ANY]))
	var it := item[i]
	for s in [1, 0, 2]:
		if outs[s] >= 0 and fc[s] == it and _out_ok(outs[s], i):
			return outs[s]
	for n in 3:
		var s := (start + n) % 3
		if outs[s] >= 0 and fc[s] == F_ANY and _out_ok(outs[s], i):
			ptr[i] = (s + 1) % 3
			return outs[s]
	for s in [1, 0, 2]:
		if outs[s] >= 0 and fc[s] == F_OVERFLOW and _out_ok(outs[s], i):
			return outs[s]
	return -1


## Merger t accepts a mover from i only if i is next in rotation among ready inputs (back, left, right).
func _merger_allows(t: int, i: int) -> bool:
	var d := dir[t]
	var winner := -1
	var wslot := 0
	var p := ptr[t]
	for n in 3:
		var s := (p + n) % 3
		var od := d if s == 0 else ((d + 1) % 4 if s == 1 else (d + 3) % 4)  # side the input lies on
		var x := t % width - DIRS[od].x
		var y := t / width - DIRS[od].y
		if x < 0 or y < 0 or x >= width or y >= height:
			continue
		var c := y * width + x
		if dir[c] == 255 or item[c] < 0 or progress[c] < ticks_per_cell or hp[c] < stall_hp:
			continue
		var facing := dir[c] == od
		if kind[c] >= 1 and kind[c] <= 3:
			facing = _splitter_only_feeds(c, t)  # region K4: sole-output splitter takes its turn
		if facing:
			winner = c
			wslot = s
			break
	if winner < 0 or winner == i:
		if winner == i:
			ptr[t] = (wslot + 1) % 3
		return true
	return false


func _node_hash(h: int) -> int:
	for i in width * height:
		if kind[i] != 0:
			h = (h * 31 + i * 5 + kind[i]) & 0x7fffffff
			h = (h * 31 + ptr[i]) & 0x7fffffff
			var f = filters.get(i)
			if f != null:
				for s in 3:
					h = (h * 31 + String(f[s]).hash()) & 0x7fffffff
	return h
# endregion
