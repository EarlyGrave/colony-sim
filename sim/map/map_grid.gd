class_name MapGrid
extends RefCounted
## Tile grid: terrain, essence deposits, mining designations, zones.
## Pure data + queries; changes are announced through the bus.

enum Tile { GROUND = 0, ROCK = 1, DEPOSIT = 2 }

const NEIGHBORS_4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const NEIGHBORS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
]

var width: int
var height: int
var tiles: PackedByteArray
var deposit_amount: PackedInt32Array
var mine_designated: PackedByteArray
var _mine_set: Dictionary = {}
var _mine_sorted := PackedInt32Array()
var _mine_dirty := false
## Zone id per cell ("" = none).
var zone_ids: PackedStringArray
## Ore destroyed without being mined (cave-ins), for deposit accounting.
var deposit_lost := 0

var _bus: Object
# region A1a: infinite resource nodes (live on DEPOSIT tiles; res 0 = legacy finite deposit)
## Resource byte per cell (NodeData.res_name), 0 = none.
var node_res: PackedByteArray
## Purity byte per cell (1 impure, 2 normal, 3 pure), 0 = none.
var node_purity: PackedByteArray
## Fractional yield carried per node between mining cycles.
var node_carry: PackedFloat32Array
var biome_id := "start"
# endregion


func _init(w: int, h: int, bus: Object = null) -> void:
	width = w
	height = h
	_bus = bus
	tiles.resize(w * h)
	tiles.fill(Tile.GROUND)
	deposit_amount.resize(w * h)
	deposit_amount.fill(0)
	mine_designated.resize(w * h)
	mine_designated.fill(0)
	node_res.resize(w * h)  # region A1a
	node_res.fill(0)
	node_purity.resize(w * h)
	node_purity.fill(0)
	node_carry.resize(w * h)
	node_carry.fill(0.0)
	zone_ids.resize(w * h)
	zone_ids.fill("")


func idx(c: Vector2i) -> int:
	return c.y * width + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func get_tile(c: Vector2i) -> int:
	return tiles[idx(c)]


func set_tile(c: Vector2i, t: int, amount := 0) -> void:
	var i := idx(c)
	tiles[i] = t
	deposit_amount[i] = amount if t == Tile.DEPOSIT else 0
	if t != Tile.DEPOSIT or amount > 0:  # region A1a: a plain tile change drops any node
		node_res[i] = 0
		node_purity[i] = 0
		node_carry[i] = 0.0
	if t != Tile.DEPOSIT:
		if mine_designated[i] != 0:
			_mine_set.erase(i)
			_mine_dirty = true
		mine_designated[i] = 0
	if _bus:
		_bus.tile_changed.emit(c)


func is_passable(c: Vector2i) -> bool:
	return in_bounds(c) and tiles[idx(c)] == Tile.GROUND


func is_deposit(c: Vector2i) -> bool:
	return in_bounds(c) and tiles[idx(c)] == Tile.DEPOSIT


# region A1a
func is_node(c: Vector2i) -> bool:
	return in_bounds(c) and node_res[idx(c)] != 0 and tiles[idx(c)] == Tile.DEPOSIT


func node_resource(c: Vector2i) -> String:
	return NodeData.res_name(node_res[idx(c)])


func node_purity_id(c: Vector2i) -> String:
	return NodeData.PURITY_IDS[node_purity[idx(c)]]


func node_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in node_res.size():
		if node_res[i] != 0 and tiles[i] == Tile.DEPOSIT:
			out.append(Vector2i(i % width, i / width))
	return out


## One hand-mining cycle: items = base * mult * purity_mult, fractions carried
## on the node. Never depletes the node. Returns whole items produced.
func mine_node(c: Vector2i, base_yield: float, mult := 1.0) -> int:
	var i := idx(c)
	var v := base_yield * mult * NodeData.purity_mult(NodeData.res_name(node_res[i]), node_purity[i]) + node_carry[i]
	var n := int(floor(v + 0.0001))
	node_carry[i] = v - n
	return n


# endregion
func get_deposit_amount(c: Vector2i) -> int:
	return deposit_amount[idx(c)]


## Turns a deposit into rock; its remaining ore is lost.
func collapse_deposit(c: Vector2i) -> void:
	if not is_deposit(c):
		return
	deposit_lost += get_deposit_amount(c)
	set_tile(c, Tile.ROCK)


## Removes up to `amount` ore from a deposit. Returns how much was taken.
## A depleted deposit turns into ground.
func take_from_deposit(c: Vector2i, amount: int) -> int:
	var i := idx(c)
	if tiles[i] != Tile.DEPOSIT:
		return 0
	if node_res[i] != 0:  # region A1a: compat shim, nodes are infinite
		return amount
	var taken := mini(amount, deposit_amount[i])
	deposit_amount[i] -= taken
	if deposit_amount[i] <= 0:
		set_tile(c, Tile.GROUND)
	return taken


func total_deposit_amount() -> int:
	var s := 0
	for a in deposit_amount:
		s += a
	return s


## Designated cell indices in ascending order (cached; rebuilt only after a change).
func mine_indices() -> PackedInt32Array:
	if _mine_dirty:
		var keys: Array = _mine_set.keys()
		keys.sort()
		_mine_sorted = PackedInt32Array(keys)
		_mine_dirty = false
	return _mine_sorted


func is_mine_designated(c: Vector2i) -> bool:
	return mine_designated[idx(c)] != 0


func set_mine_designated(c: Vector2i, on: bool) -> void:
	if not is_deposit(c):
		return
	var i := idx(c)
	if (mine_designated[i] != 0) != on:
		if on:
			_mine_set[i] = true
		else:
			_mine_set.erase(i)
		_mine_dirty = true
	mine_designated[i] = 1 if on else 0
	if _bus:
		_bus.designation_changed.emit(c)


func get_zone(c: Vector2i) -> String:
	return zone_ids[idx(c)]


func set_zone(c: Vector2i, zone_id: String) -> void:
	zone_ids[idx(c)] = zone_id
	if _bus:
		_bus.zone_changed.emit(c)


## Passable neighbor of a solid cell to stand on while working it.
func is_adjacent_to_passable(c: Vector2i) -> bool:
	for d in NEIGHBORS_4:
		if is_passable(c + d):
			return true
	return false


## Stable hash of terrain state, for determinism tests.
func checksum() -> int:
	var h := hash(tiles)
	h = hash([h, hash(deposit_amount), width, height, hash(node_res), hash(node_purity)])  # region A1a
	return h
