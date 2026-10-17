class_name HaulGiver
extends WorkGiver


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "haul"
	work_type = "hauling"


func find(c: Colonist) -> Job:
	var js := sim.jobs
	var best: Job = null
	var best_d := 1 << 30
	# 1) Building outputs -> storage.
	if sim.buildings:
		for b: Building in sim.buildings.list:
			var key := "bout:%d" % b.id
			if b.output.is_empty() or not js._free(c, key) or not sim.pathfinder.reachable(c.cell, b.cell):
				continue
			var d := c.cell.distance_squared_to(b.cell)
			if d >= best_d:
				continue
			for item: String in b.output:
				var dst := js._storage_for(item, b.cell, c)
				if dst.x >= 0:
					best = js._haul(HaulJob.Src.BUILDING_OUT, JobSystem.NO_CELL, b.id, HaulJob.Dst.CELL, dst, -1, item, int(b.output[item]))
					best.reservations.append(key)
					best.fail_key = key
					best_d = d
					break
	# 2) Feed buildings that need input; 3) loose stacks -> storage.
	for cell: Vector2i in sim.items.stacks:
		var key := "cell:%d,%d" % [cell.x, cell.y]
		var d := c.cell.distance_squared_to(cell)
		if d >= best_d or not js._free(c, key):
			continue
		var item := sim.items.item_at(cell)
		var count := sim.items.count_at(cell)
		if not sim.pathfinder.reachable(c.cell, cell):
			continue
		var job: Job = null
		var b := js._building_needing(item, cell, c)
		var feed := 0
		if b != null:
			feed = js._reserve_limited(item, cell, mini(count, b.input_space(item)))
		if b != null and feed > 0:
			job = js._haul(HaulJob.Src.GROUND, cell, -1, HaulJob.Dst.BUILDING_IN, JobSystem.NO_CELL, b.id, item, feed)
		elif not sim.items.is_stored(cell):
			var dst := js._storage_for(item, cell, c)
			if dst.x >= 0:
				job = js._haul(HaulJob.Src.GROUND, cell, -1, HaulJob.Dst.CELL, dst, -1, item, count)
		if job != null:
			job.reservations.append(key)
			job.fail_key = key
			best = job
			best_d = d
	return best
