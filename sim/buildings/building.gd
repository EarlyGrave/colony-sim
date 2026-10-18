class_name Building
extends RefCounted
## A placed building instance. Behaviour driven by its def (data/buildings.json).

var id: int
var def_id: String
var def: Dictionary
var cell: Vector2i  # top-left
var size: Vector2i
var hp: float
var max_hp: float
## 0..100. Machines wear out; at 0 they break and stop working.
var condition := 100.0
var broken := false
var destroyed := false
var input: Dictionary = {}  # item -> count
var output: Dictionary = {}  # item -> count
## region quality: item -> Array[String], one quality per output unit (FIFO), tracked items only.
var output_q: Dictionary = {}
var recipe: Dictionary = {}
var recipe_id := ""
var progress := 0
var turret_cooldown := 0
# region ammo
var ammo := 0
var ammo_policy := "normal"
var ammo_empty_flagged := false
# endregion
# region crafting
## Ingredients wanted by active bills (item -> true); refreshed by BillSystem.
var bill_items: Dictionary = {}
# endregion
# region A2a
## Station recipes of a processor machine (recipe ids, sorted); miner: node cell + fractional output.
var station_recipes: Array[String] = []
var station_defs: Dictionary = {}
var node_cell := Vector2i(-1, -1)
var mach_acc := 0.0
var mach_items := 0
# endregion


func _init(p_id: int, p_def_id: String, p_def: Dictionary, p_cell: Vector2i, recipes: Dictionary) -> void:
	id = p_id
	def_id = p_def_id
	def = p_def
	cell = p_cell
	size = Vector2i(int(def["size"][0]), int(def["size"][1]))
	max_hp = float(def["max_hp"])
	hp = max_hp
	if def.has("recipe"):
		recipe_id = def["recipe"]
		recipe = recipes[recipe_id]
	if def.get("machine", "") == "processor":  # region A2a
		for rid: String in recipes:
			if def_id in recipes[rid].get("station", []):
				station_recipes.append(rid)
				station_defs[rid] = recipes[rid]
		station_recipes.sort()


# region T4
## AI chip slots of this building (data `chip_slots`; 0 for miners and everything else).
func chip_slots() -> int:
	return int(def.get("chip_slots", 0))
# endregion


func footprint() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			out.append(cell + Vector2i(x, y))
	return out


func contains(c: Vector2i) -> bool:
	return c.x >= cell.x and c.y >= cell.y and c.x < cell.x + size.x and c.y < cell.y + size.y


## Center in cell units (float), e.g. (10.5, 10.5) for a 2x2 at (10, 10)... minus half.
func center() -> Vector2:
	return Vector2(cell) + Vector2(size) * 0.5 - Vector2(0.5, 0.5)


## Footprint cell closest to `p` (for attack range checks).
func nearest_cell_to(p: Vector2i) -> Vector2i:
	return Vector2i(clampi(p.x, cell.x, cell.x + size.x - 1), clampi(p.y, cell.y, cell.y + size.y - 1))


func distance_to(p: Vector2) -> float:
	var n := Vector2(clampf(p.x, cell.x, cell.x + size.x - 1), clampf(p.y, cell.y, cell.y + size.y - 1))
	return n.distance_to(p)


func is_machine() -> bool:
	return def.has("recipe") or def.has("turret") or def.has("bills") or def.has("machine")


# --- Production buffers -------------------------------------------------------

func input_space(item_id: String) -> int:
	if def.get("port_building", false):  # region A2b
		return PortLink.manual_input_space(self)
	if not station_recipes.is_empty():  # region A2a: processor takes inputs of any station recipe
		for rid in station_recipes:
			if station_defs[rid]["inputs"].has(item_id):
				return int(def["input_capacity"]) - int(input.get(item_id, 0))
		return 0
	if bill_items.has(item_id):  # region crafting
		return int(def["input_capacity"]) - int(input.get(item_id, 0))
	if recipe.is_empty() or not recipe["inputs"].has(item_id):
		return 0
	return int(def["input_capacity"]) - int(input.get(item_id, 0))


func add_input(item_id: String, n: int) -> int:
	var k := mini(n, input_space(item_id))
	if k > 0:
		input[item_id] = int(input.get(item_id, 0)) + k
	return k


func take_output(item_id: String, n: int) -> int:
	var k := mini(n, int(output.get(item_id, 0)))
	if k > 0:
		output[item_id] -= k
		if output_q.has(item_id):  # region quality
			output_q[item_id] = output_q[item_id].slice(k)
			if output_q[item_id].is_empty():
				output_q.erase(item_id)
		if output[item_id] <= 0:
			output.erase(item_id)
	return k


## region quality: quality of the next output unit and how many leading units share it.
func next_run(item_id: String, n: int) -> Dictionary:
	var qs: Array = output_q.get(item_id, [])
	if qs.is_empty():
		return {"q": "", "count": mini(n, int(output.get(item_id, 0)))}
	var k := 1
	while k < mini(n, qs.size()) and qs[k] == qs[0]:
		k += 1
	return {"q": qs[0], "count": k}


func output_total() -> int:
	var s := 0
	for k in output:
		s += int(output[k])
	return s


func has_recipe_inputs() -> bool:
	if recipe.is_empty():
		return false
	for item in recipe["inputs"]:
		if int(input.get(item, 0)) < int(recipe["inputs"][item]):
			return false
	return true


func has_output_room() -> bool:
	var add := 0
	for item in recipe["outputs"]:
		add += int(recipe["outputs"][item])
	return output_total() + add <= int(def["output_capacity"])


func can_run_recipe() -> bool:
	return not broken and not destroyed and has_recipe_inputs() and has_output_room()


func needs_repair(sim: Simulation) -> bool:
	if destroyed or bool(def.get("blocks_movement", false)):
		return false  # walls are rebuilt, not repaired
	if broken or hp < max_hp:
		return true
	return is_machine() and condition < float(sim.defs.balance["repair"]["threshold"]) * 100.0
