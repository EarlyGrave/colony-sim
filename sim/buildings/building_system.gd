class_name BuildingSystem
extends RefCounted
## Placement, production, wear, damage and destruction of buildings.

var sim: Simulation
var list: Array[Building] = []
var occupancy: Dictionary = {}  # Vector2i -> building id
var refined_batches := 0
var first_refine_done := false
var _next_id := 1


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func get_by_id(id: int) -> Building:
	for b in list:
		if b.id == id:
			return b
	return null


func at(c: Vector2i) -> Building:
	return get_by_id(int(occupancy[c])) if occupancy.has(c) else null


func occupied(c: Vector2i) -> bool:
	return occupancy.has(c)


## Empty string if `def_id` can be placed at `c`, otherwise the reason.
func placement_error(def_id: String, c: Vector2i, check_cost := true) -> String:
	if not sim.defs.buildings.has(def_id):
		return "Неизвестная постройка"
	var def: Dictionary = sim.defs.buildings[def_id]
	for y in int(def["size"][1]):
		for x in int(def["size"][0]):
			var p := c + Vector2i(x, y)
			if not sim.map.is_passable(p):
				return "Мешает рельеф"
			if occupancy.has(p):
				return "Место занято"
			if sim.items.stacks.has(p):
				return "Мешают предметы"
			if sim.map.get_zone(p) != "":
				return "Мешает зона"
	if check_cost:
		for item in def["cost"]:
			if sim.items.count_stored(item) < int(def["cost"][item]):
				return "Не хватает: " + sim.defs.items[item]["name"]
	return ""


## Places a building, paying its cost from storage when `pay` is true.
## Returns null if placement is invalid.
func place(def_id: String, c: Vector2i, pay := true) -> Building:
	if placement_error(def_id, c, pay) != "":
		return null
	var def: Dictionary = sim.defs.buildings[def_id]
	if pay:
		for item in def["cost"]:
			var n := int(def["cost"][item])
			sim.items.consume_stored(item, n, c)
			sim.ledger.record_consumed(item, n, "construction")
	var b := Building.new(_next_id, def_id, def, c, sim.defs.recipes)
	_next_id += 1
	list.append(b)
	for p in b.footprint():
		occupancy[p] = b.id
	sim.bus.building_placed.emit(b.id)
	return b


## One tick of operator work on a production building.
## Returns true when a batch completed this tick.
func work(b: Building) -> bool:
	if not b.can_run_recipe():
		return false
	b.progress += 1
	if b.progress < int(b.recipe["work_ticks"]):
		return false
	b.progress = 0
	for item in b.recipe["inputs"]:
		var n := int(b.recipe["inputs"][item])
		b.input[item] -= n
		if b.input[item] <= 0:
			b.input.erase(item)
		sim.ledger.record_consumed(item, n, "recipe")
	for item in b.recipe["outputs"]:
		var n := int(b.recipe["outputs"][item])
		b.output[item] = int(b.output.get(item, 0)) + n
		sim.ledger.record_produced(item, n, "recipe")
	refined_batches += 1
	wear(b, float(b.def.get("wear_per_batch", 0.0)))
	sim.bus.batch_refined.emit(b.id, b.recipe_id)
	if not first_refine_done:
		first_refine_done = true
		sim.bus.first_refine_done.emit()
	return true


func wear(b: Building, amount: float) -> void:
	if amount <= 0.0 or b.broken:
		return
	b.condition = maxf(0.0, b.condition - amount)
	if b.condition <= 0.0:
		b.broken = true
		b.progress = 0
		sim.bus.building_broken.emit(b.id)


func repair(b: Building) -> void:
	b.condition = 100.0
	b.hp = b.max_hp
	b.broken = false
	sim.bus.building_repaired.emit(b.id)


func damage(b: Building, amount: float) -> void:
	if b.destroyed:
		return
	b.hp -= amount
	if b.hp <= 0.0:
		destroy(b)


## Removes the building. Its stored items spill onto the ground.
func destroy(b: Building) -> void:
	_remove(b)
	if b.def.get("critical", false):
		sim.end_game("hq_destroyed")


## Player deconstruction: refunds a fraction of the cost, spills buffers.
## Returns false if there is nothing deconstructible at `c`.
func deconstruct(c: Vector2i) -> bool:
	var b := at(c)
	if b == null or not bool(b.def.get("deconstructible", true)):
		return false
	_remove(b)
	var frac := float(sim.defs.balance["construction"]["refund_fraction"])
	for item: String in b.def["cost"]:
		var n := int(floor(int(b.def["cost"][item]) * frac))
		if n > 0:
			sim.ledger.record_produced(item, n, "refund")
			sim.items.drop(b.cell, item, n)
	return true


func _remove(b: Building) -> void:
	if b.destroyed:
		return
	b.destroyed = true
	for key in ["op:%d", "rep:%d", "bin:%d"]:
		sim.jobs.reserved.erase(key % b.id)
	list.erase(b)
	for p in b.footprint():
		occupancy.erase(p)
	for buf: Dictionary in [b.input, b.output]:
		for item: String in buf:
			sim.items.drop(b.cell, item, int(buf[item]))
		buf.clear()
	if b.def.get("shelter", false):
		for c in sim.colonists.list:
			if c.hidden and b.contains(c.cell):
				c.hidden = false
	sim.bus.building_destroyed.emit(b.id)


func find_shelter(near: Vector2i) -> Building:
	var best: Building = null
	var best_d := 1 << 30
	for b in list:
		if b.def.get("shelter", false) and sim.pathfinder.reachable(near, b.cell):
			var d := near.distance_squared_to(b.cell)
			if d < best_d:
				best = b
				best_d = d
	return best


func count_item(item_id: String) -> int:
	var s := 0
	for b in list:
		s += int(b.input.get(item_id, 0)) + int(b.output.get(item_id, 0))
	return s


func count_of(def_id: String) -> int:
	var n := 0
	for b in list:
		if b.def_id == def_id:
			n += 1
	return n
