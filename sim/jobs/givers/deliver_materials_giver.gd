class_name DeliverMaterialsGiver
extends WorkGiver
## Brings blueprint cost items from storage into the blueprint.


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "deliver_materials"
	work_type = "hauling"


func find(c: Colonist) -> Job:
	var js := sim.jobs
	var best: Job = null
	var best_d := 1 << 30
	for bp: Blueprint in sim.buildings.blueprints:
		if sim.buildings.bp_stand(bp, c.cell).x < 0:
			continue
		for item: String in bp.def["cost"]:
			var key := "bpmat:%d:%s" % [bp.id, item]
			if bp.missing(item) <= 0 or not js._free(c, key):
				continue
			for cell: Vector2i in sim.items.stacks:
				var ckey := "cell:%d,%d" % [cell.x, cell.y]
				if not sim.items.is_stored(cell) or sim.items.item_at(cell) != item \
						or not js._free(c, ckey) or not sim.pathfinder.reachable(c.cell, cell):
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
