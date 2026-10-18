class_name LogisticsSystem
extends RefCounted
## Belt network owner. Ticks after colonists, before threats.
## Public API for commands (A1d) and ports (A2b):
##   can_place_belt(cell), place_belt_cell(cell, dir), remove_belt_cell(cell),
##   belt_dir(cell), item_id(name), item_name(id), insert_item(cell, name),
##   take_ready_item(cell) -> String, state_hash(). Raw access via `belts`.

var sim: Simulation
var belts: BeltGrid
var _names: Array[String] = []


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	var cfg: Dictionary = sim.defs.balance.get("automation", {})
	belts = BeltGrid.new(sim.map.width, sim.map.height, int(cfg.get("belt_ticks_per_cell", 5)))


func tick() -> void:
	belts.step()


## In bounds and passable ground (rock/deposit/buildings block via map passability).
func can_place_belt(c: Vector2i) -> bool:
	return belts.in_bounds(c) and sim.map.is_passable(c)


func place_belt_cell(c: Vector2i, d: int) -> bool:
	if not can_place_belt(c):
		return false
	return belts.set_belt(c, d)


func remove_belt_cell(c: Vector2i) -> bool:
	if not belts.has_belt(c):
		return false
	belts.remove_belt(c)
	return true


func belt_dir(c: Vector2i) -> int:
	return belts.belt_dir(c)


func item_id(item_name_: String) -> int:
	var i := _names.find(item_name_)
	if i < 0:
		_names.append(item_name_)
		i = _names.size() - 1
	return i


func item_name(id: int) -> String:
	return _names[id] if id >= 0 and id < _names.size() else ""


func insert_item(c: Vector2i, item_name_: String) -> bool:
	return belts.insert(c, item_id(item_name_))


func take_ready_item(c: Vector2i) -> String:
	return item_name(belts.take_ready(c))


func state_hash() -> int:
	return (belts.state_hash() * 31 + belts.belt_count) & 0x7fffffff
