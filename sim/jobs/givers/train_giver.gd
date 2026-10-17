class_name TrainGiver
extends WorkGiver
## Low-priority training at a free training dummy (daily xp cap per colonist).


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "train"
	work_type = "training"


func find(c: Colonist) -> Job:
	if sim.buildings == null or sim.alarm or sim.idle_work.training_left(c) <= 0.0:
		return null
	var skill := sim.idle_work.training_skill(c)
	if skill == "":
		return null
	var def_id := str(sim.defs.idle_work["training"]["building"])
	var best: Building = null
	var best_d := 1 << 30
	for b: Building in sim.buildings.list:
		var key := "train:%d" % b.id
		if b.def_id != def_id or b.broken or not sim.jobs._free(c, key) or not sim.pathfinder.reachable(c.cell, b.cell):
			continue
		var d := c.cell.distance_squared_to(b.cell)
		if d < best_d:
			best = b
			best_d = d
	if best == null:
		return null
	var job := TrainJob.new(best.id, skill)
	job.reservations.append("train:%d" % best.id)
	job.fail_key = "train:%d" % best.id
	return job
