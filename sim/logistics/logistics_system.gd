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
	# region T3
	var ld: Dictionary = sim.defs.balance.get("line_damage", {})
	belts.max_hp = float(ld.get("belt_hp", 40))
	belts.stall_hp = belts.max_hp * float(ld.get("stall_frac", 0.3))
	# endregion


func tick() -> void:
	PortLink.tick(sim)  # region A2b
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


# Command-facing API used by Simulation (region A1d). Dirs: 0=N, 1=E, 2=S, 3=W.
func place_path(cells: Array, dirs: Array) -> void:
	for i in cells.size():
		place_belt_cell(cells[i], int(dirs[i]))


func remove_at(c: Vector2i) -> bool:
	return remove_belt_cell(c)


func set_dir(c: Vector2i, d: int) -> bool:
	return has_belt(c) and place_belt_cell(c, d)


func has_belt(c: Vector2i) -> bool:
	return belt_dir(c) >= 0


func dir_at(c: Vector2i) -> int:
	return belt_dir(c)


## Deterministic snapshot for SaveGame.state_hash.
func state_parts() -> Array:
	return [belts.belt_count, belts.state_hash()]

# region T3
## Belt tile bite (ThreatSystem._attack_structure). Emits nothing; stall is derived from hp.
func damage_belt(c: Vector2i, amount: float) -> bool:
	return belts.damage_belt(c, amount)


## Pay the repair cost from stored items and restore the tile; false if unaffordable.
func repair_belt(c: Vector2i) -> bool:
	if not belts.is_damaged(c):
		return false
	var cost: Dictionary = sim.defs.balance["line_damage"]["belt_repair_cost"]
	if not sim.buildings.pay_repair(cost, c):
		return false
	belts.repair_belt(c)
	return true


func belt_needs_repair(c: Vector2i) -> bool:
	return belts.is_damaged(c)
# endregion
