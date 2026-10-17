class_name BillSystem
extends RefCounted
## Bills (production orders) on workbench-like buildings.
## Building.recipe is switched here between batches, so the existing operate
## and haul machinery works unchanged.

var sim: Simulation
## building id -> Array of Bill, insertion ordered.
var bills: Dictionary = {}
## building id -> bill id currently selected for the next/running batch.
var _active: Dictionary = {}
var _next_id := 1


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	sim.listen(sim.bus.batch_refined, _on_batch)


func bills_of(b: Building) -> Array:
	return bills.get(b.id, [])


func get_bill(b: Building, bill_id: int) -> Bill:
	for bl: Bill in bills_of(b):
		if bl.id == bill_id:
			return bl
	return null


## True if `bill` still wants another batch.
func wanted(bill: Bill) -> bool:
	if bill.paused:
		return false
	match bill.mode:
		"count":
			return bill.done < bill.target
		"until":
			var item := _product(bill)
			return item != "" and sim.items.count_world(item) < bill.target
	return bill.mode == "forever"


## True if some wanted bill of `b` uses `item_id` as an ingredient.
func needs_item(b: Building, item_id: String) -> bool:
	for bl: Bill in bills_of(b):
		if wanted(bl) and sim.defs.recipes[bl.recipe_id]["inputs"].has(item_id):
			return true
	return false


func add_bill(b: Building, recipe_id: String, mode: String, target: int) -> int:
	if b == null or not b.def.get("bills", false) or not sim.defs.recipes.has(recipe_id):
		return -1
	if not b.def_id in sim.defs.recipes[recipe_id].get("benches", []):
		return -1
	if not mode in sim.defs.crafting["modes"] or target < 0:
		return -1
	if not bills.has(b.id):
		bills[b.id] = []
	var bl := Bill.new(_next_id, recipe_id, mode, target)
	_next_id += 1
	bills[b.id].append(bl)
	sim.bus.bills_changed.emit(b.id)
	return bl.id


func remove_bill(b: Building, bill_id: int) -> bool:
	var bl := get_bill(b, bill_id) if b != null else null
	if bl == null:
		return false
	bills[b.id].erase(bl)
	if _active.get(b.id, -1) == bill_id:
		_active.erase(b.id)
	sim.bus.bills_changed.emit(b.id)
	return true


func update_bill(b: Building, bill_id: int, mode: String, target: int, paused: bool) -> bool:
	var bl := get_bill(b, bill_id) if b != null else null
	if bl == null or not mode in sim.defs.crafting["modes"] or target < 0:
		return false
	if mode != bl.mode:
		bl.done = 0
	bl.mode = mode
	bl.target = target
	bl.paused = paused
	sim.bus.bills_changed.emit(b.id)
	return true


## Once per tick: between batches, point each bills building at the first
## wanted bill (preferring one whose ingredients are already inside).
func tick() -> void:
	for b: Building in sim.buildings.list:
		if not b.def.get("bills", false):
			continue
		b.bill_items.clear()
		for bl: Bill in bills_of(b):
			if wanted(bl):
				for item: String in sim.defs.recipes[bl.recipe_id]["inputs"]:
					b.bill_items[item] = true
		if b.progress == 0:
			_select(b)


func _select(b: Building) -> void:
	var pick: Bill = null
	for bl: Bill in bills_of(b):
		if not wanted(bl):
			continue
		if pick == null:
			pick = bl
		if _has_inputs(b, bl):
			pick = bl
			break
	if pick == null:
		b.recipe = {}
		b.recipe_id = ""
		_active.erase(b.id)
		return
	b.recipe = sim.defs.recipes[pick.recipe_id]
	b.recipe_id = pick.recipe_id
	_active[b.id] = pick.id


func _has_inputs(b: Building, bl: Bill) -> bool:
	var inputs: Dictionary = sim.defs.recipes[bl.recipe_id]["inputs"]
	for item: String in inputs:
		if int(b.input.get(item, 0)) < int(inputs[item]):
			return false
	return true


func _product(bill: Bill) -> String:
	for item: String in sim.defs.recipes[bill.recipe_id]["outputs"]:
		return item
	return ""


func _on_batch(building_id: int, _recipe_id: String) -> void:
	var b := sim.buildings.get_by_id(building_id)
	if b == null or not _active.has(building_id):
		return
	var bl := get_bill(b, int(_active[building_id]))
	if bl != null:
		bl.done += 1
		sim.bus.bills_changed.emit(building_id)
	# Re-select now so no other colonist starts a stale batch this tick.
	_select(b)
