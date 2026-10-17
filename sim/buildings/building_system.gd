class_name BuildingSystem
extends RefCounted
## Placement, production, wear, damage and destruction of buildings.

var sim: Simulation
var list: Array[Building] = []
var occupancy: Dictionary = {}  # Vector2i -> building id
var refined_batches := 0
var first_refine_done := false
## Operator of the batch being finished (read by ContaminationSystem on batch_refined).
var batch_operator: Colonist = null
var _next_id := 1
# region construction
var blueprints: Array[Blueprint] = []
var bp_occupancy: Dictionary = {}  # Vector2i -> blueprint id
var _next_bp_id := 1
# endregion


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
	return occupancy.has(c) or bp_occupancy.has(c)


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
			if occupancy.has(p) or bp_occupancy.has(p):
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
	if b.def.get("blocks_movement", false):  # region construction
		_block(b, true)
	if sim.ammo != null:  # region ammo
		sim.ammo.init_building(b)
	sim.bus.building_placed.emit(b.id)
	return b


## One tick of operator work on a production building.
## Rule "refine_cap": true when no NEW batch may start (contamination at the
## player's limit). A batch already in progress is always finished.
func refining_capped() -> bool:
	if not sim.is_rule_on("refine_cap"):
		return false
	var limit := float(sim.defs.rules["refine_cap"]["max_contamination_percent"])
	return sim.contamination.fraction() * 100.0 >= limit


func may_operate(b: Building) -> bool:
	if sim.crises.flag("refine_lock") and _is_refining(b):  # region crises
		return false
	return b.can_run_recipe() and (b.progress > 0 or not refining_capped())


# region crises
func _is_refining(b: Building) -> bool:
	for item: String in b.recipe.get("outputs", {}):
		if sim.defs.items[item].get("contaminates", false):
			return true
	return false
# endregion

## Returns true when a batch completed this tick.
func work(b: Building, steps := 1, operator: Colonist = null) -> bool:
	if not b.can_run_recipe() or steps <= 0:
		return false
	b.progress += steps
	if b.progress < int(b.recipe["work_ticks"]):
		return false
	b.progress = 0
	# region perks
	var saved_item := ""
	var craft_save := -sim.perks.mod(operator, "craft_input")
	if craft_save > 0.0 and sim.rng.randf() < craft_save:
		for item in b.recipe["inputs"]:  # first ingredient is spared one unit
			saved_item = str(item)
			break
	# endregion
	for item in b.recipe["inputs"]:
		var n := int(b.recipe["inputs"][item])
		if item == saved_item:
			n = maxi(0, n - 1)  # stays in the input buffer, never consumed
		b.input[item] -= n
		if b.input[item] <= 0:
			b.input.erase(item)
		sim.ledger.record_consumed(item, n, "recipe")
	for item in b.recipe["outputs"]:
		var n := int(b.recipe["outputs"][item])
		# region perks
		if sim.defs.items[item].get("contaminates", false):
			if sim.perks.consume_flag(operator, "no_waste_next_batch"):
				n = 0
			else:
				n = PerkHooks.scaled(operator, "waste_mult", float(n), 1.0 + sim.perks.mod(operator, "waste_mult"))
		elif b.recipe_id == "refine_essence":  # region crises
			n = int(round(float(n) * sim.crises.mult("refine_output_mult")))
		if n <= 0:
			continue
		# endregion
		b.output[item] = int(b.output.get(item, 0)) + n
		if sim.quality.tracked(item):  # region quality
			var q := sim.quality.roll(item, operator, b.def_id)
			if not b.output_q.has(item):
				b.output_q[item] = []
			for i in n:
				b.output_q[item].append(q)
		sim.ledger.record_produced(item, n, "recipe")
	refined_batches += 1
	wear(b, float(b.def.get("wear_per_batch", 0.0)))
	batch_operator = operator  # region perks
	sim.bus.batch_refined.emit(b.id, b.recipe_id)
	batch_operator = null
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
	if bp_occupancy.has(c):  # region construction
		return cancel_blueprint(get_blueprint(int(bp_occupancy[c])))
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
	for key in ["op:%d", "rep:%d", "bin:%d", "bed:%d"]:
		sim.jobs.reserved.erase(key % b.id)
	list.erase(b)
	for p in b.footprint():
		occupancy.erase(p)
	if b.def.get("blocks_movement", false):  # region construction
		_block(b, false)
	for buf: Dictionary in [b.input, b.output]:
		for item: String in buf:
			sim.items.drop(b.cell, item, int(buf[item]))
		buf.clear()
	if sim.ammo != null:  # region ammo
		sim.ammo.spill(b)
	if b.def.get("shelter", false):
		for c in sim.colonists.list:
			if c.alive and c.hidden and b.contains(c.cell):
				c.hidden = false
				_collapse_hit(c)
	sim.bus.building_destroyed.emit(b.id)


## A shelter falling on its occupants: heavy injuries (some may die).
func _collapse_hit(c: Colonist) -> void:
	var cc: Dictionary = sim.defs.health.get("shelter_collapse", {})
	for i in int(cc.get("hits", 0)):
		sim.health.apply_damage(c, float(sim.rng.randi_range(int(cc["damage_min"]), int(cc["damage_max"]))), "", str(cc["kind"]))


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
	for bp in blueprints:  # region construction
		s += int(bp.delivered.get(item_id, 0))
	return s


func count_of(def_id: String) -> int:
	var n := 0
	for b in list:
		if b.def_id == def_id:
			n += 1
	return n


# region construction
## Plans a building: the cells are reserved, work givers do the rest.
## Returns null if placement is invalid. Cost is NOT required up front.
func place_blueprint(def_id: String, c: Vector2i) -> Blueprint:
	if placement_error(def_id, c, false) != "":
		return null
	var bp := Blueprint.new(_next_bp_id, def_id, sim.defs.buildings[def_id], c,
		float(sim.defs.balance["construction"]["default_build_work"]))
	_next_bp_id += 1
	blueprints.append(bp)
	for p in bp.footprint():
		bp_occupancy[p] = bp.id
	sim.bus.blueprint_placed.emit(bp.id)
	return bp


func get_blueprint(id: int) -> Blueprint:
	for bp in blueprints:
		if bp.id == id:
			return bp
	return null


func blueprint_at(c: Vector2i) -> Blueprint:
	return get_blueprint(int(bp_occupancy[c])) if bp_occupancy.has(c) else null


func _drop_blueprint(bp: Blueprint) -> void:
	blueprints.erase(bp)
	for p in bp.footprint():
		bp_occupancy.erase(p)
	for key in ["bp:%d" % bp.id]:
		sim.jobs.reserved.erase(key)
	for item: String in bp.def["cost"]:
		sim.jobs.reserved.erase("bpmat:%d:%s" % [bp.id, item])


## Removes a blueprint; delivered materials spill onto the ground (nothing is lost).
func cancel_blueprint(bp: Blueprint) -> bool:
	if bp == null:
		return false
	_drop_blueprint(bp)
	for item: String in bp.delivered:
		if int(bp.delivered[item]) > 0:
			sim.items.drop(bp.cell, item, int(bp.delivered[item]))
	bp.delivered.clear()
	sim.bus.blueprint_cancelled.emit(bp.id)
	return true


## Turns a fully supplied blueprint into a building; materials are consumed now.
func complete_blueprint(bp: Blueprint, builder: Colonist = null) -> Building:
	if bp == null or not bp.has_all_materials():
		return null
	_drop_blueprint(bp)
	var refunds: Dictionary = {}  # region perks
	for item: String in bp.def["cost"]:
		var n := int(bp.def["cost"][item])
		# region perks: build_cost spares a fraction of the materials (returned to the ground)
		var save_frac := -sim.perks.mod(builder, "build_cost")
		var spared := mini(n, PerkHooks.scaled(builder, "build_cost", float(n), save_frac)) if save_frac > 0.0 else 0
		refunds[item] = spared
		# endregion
		sim.ledger.record_consumed(item, n - spared, "construction")
	bp.delivered.clear()
	var b := place(bp.def_id, bp.cell, false)
	if b == null:  # cannot happen: the cells were reserved
		return null
	# region perks
	b.max_hp *= 1.0 + sim.perks.mod(builder, "building_hp")
	b.hp = b.max_hp
	for item: String in refunds:
		if int(refunds[item]) > 0:
			sim.items.drop(b.cell, item, int(refunds[item]))
	# endregion
	sim.bus.blueprint_completed.emit(bp.id, b.id)
	return b


func _block(b: Building, on: bool) -> void:
	for p in b.footprint():
		sim.pathfinder.set_blocked(p, on)
	if on:
		_evict(b)


## Moves colonists / creatures standing inside a freshly solid building out.
func _evict(b: Building) -> void:
	var movers: Array = []
	movers.append_array(sim.colonists.list)
	movers.append_array(sim.threats.enemies if sim.threats != null else [])
	for m: GridMover in movers:
		if not b.contains(m.cell):
			continue
		var spot := _nearest_walkable(m.cell)
		if spot.x >= 0:
			m.cell = spot
		m.clear_path()


func _nearest_walkable(from: Vector2i) -> Vector2i:
	for r in range(1, 8):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) == r and sim.pathfinder.is_walkable(from + Vector2i(x, y)):
					return from + Vector2i(x, y)
	return Vector2i(-1, -1)
# endregion
