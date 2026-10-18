class_name CalibrateGiver
extends WorkGiver


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "calibrate"
	work_type = "operating"


func find(c: Colonist) -> Job:
	if sim.chips == null or sim.chips.slots.is_empty():
		return null
	if c.skills.level("operating") < int(sim.defs.chips["calibrate_min_skill"]):
		return null
	var best: Building = null
	var best_d := 1 << 30
	var ids: Array = sim.chips.slots.keys()
	ids.sort()
	for bid: int in ids:
		var b := sim.buildings.get_by_id(bid)
		if b == null or not sim.chips.needs_calibration(b):
			continue
		var key := "cal:%d" % b.id
		if not sim.jobs._free(c, key) or not sim.pathfinder.reachable(c.cell, b.cell):
			continue
		var d := c.cell.distance_squared_to(b.cell)
		if d < best_d:
			best = b
			best_d = d
	if best == null:
		return null
	var j := CalibrateJob.new(best.id)
	j.reservations.append("cal:%d" % best.id)
	j.fail_key = "cal:%d" % best.id
	return j
