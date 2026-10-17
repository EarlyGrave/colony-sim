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
## Zone id per cell ("" = none).
var zone_ids: PackedStringArray
## Ore destroyed without being mined (cave-ins), for deposit accounting.
var deposit_lost := 0

var _bus: Object


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
	if t != Tile.DEPOSIT:
		mine_designated[i] = 0
	if _bus:
		_bus.tile_changed.emit(c)


func is_passable(c: Vector2i) -> bool:
	return in_bounds(c) and tiles[idx(c)] == Tile.GROUND


func is_deposit(c: Vector2i) -> bool:
	return in_bounds(c) and tiles[idx(c)] == Tile.DEPOSIT


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


func is_mine_designated(c: Vector2i) -> bool:
	return mine_designated[idx(c)] != 0


func set_mine_designated(c: Vector2i, on: bool) -> void:
	if not is_deposit(c):
		return
	mine_designated[idx(c)] = 1 if on else 0
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
	h = hash([h, hash(deposit_amount), width, height])
	return h
