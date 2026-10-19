class_name DeliverMaterialsGiver
extends WorkGiver
## Brings blueprint cost items from storage (or loose essence ore) into the blueprint.


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "deliver_materials"
	work_type = "hauling"


# region W1d
func find(c: Colonist) -> Job:
	var js := sim.jobs
	var best: Job = null
	var best_d := 1 << 30
	var stored: Dictionary = {}  # item -> stored cells in stacks order, built on first need
	for bp: Blueprint in sim.buildings.blueprints:
		var stand_ok := -1  # lazily evaluated: needs pathing, only if some item is wanted
		for item: String in bp.def["cost"]:
			var key := "bpmat:%d:%s" % [bp.id, item]
			if bp.missing(item) <= 0 or not js._free(c, key):
				continue
			if stored.is_empty():
				_index_stored(stored)
			if not stored.has(item):
				continue  # nothing in storage: skip the pathing check
			if stand_ok < 0:
				stand_ok = 1 if sim.buildings.bp_stand(bp, c.cell).x >= 0 else 0
			if stand_ok == 0:
				break
			for cell: Vector2i in stored.get(item, []):
				var ckey := "cell:%d,%d" % [cell.x, cell.y]
				if not js._free(c, ckey) or not sim.pathfinder.reachable(c.cell, cell):
					continue
				var d := c.cell.distance_squared_to(cell)
				if d >= best_d:
					continue
				var j := DeliverJob.new(bp.id, cell, item, mini(bp.missing(item), sim.items.count_at(cell)))
				j.reservations.append(key)
				j.reservations.append(ckey)
				j.fail_key = key
				best = j
				best_d = d
	return best


func _index_stored(out: Dictionary) -> void:
	out["_"] = []  # marker so an empty result is not rebuilt
	for cell: Vector2i in sim.items.stacks:
		if sim.items.is_stored(cell) or sim.items.item_at(cell) == "essence_ore":  # DB: loose ore may feed blueprints (the refinery ate it all)
			var it: String = sim.items.stacks[cell]["item"]
			if not out.has(it):
				out[it] = []
			out[it].append(cell)
# endregion
