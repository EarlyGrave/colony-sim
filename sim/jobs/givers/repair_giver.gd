class_name RepairGiver
extends WorkGiver


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "repair"
	work_type = "repair"


func find(c: Colonist) -> Job:
	if sim.buildings == null:
		return null
	var best: Building = null
	var best_d := 1 << 30
	for b: Building in sim.buildings.list:
		var key := "rep:%d" % b.id
		if not b.needs_repair(sim) or not sim.jobs._free(c, key) or not sim.pathfinder.reachable(c.cell, b.cell):
			continue
		var d := c.cell.distance_squared_to(b.cell)
		if d < best_d:
			best = b
			best_d = d
	if best == null:
		return null
	var j := RepairJob.new(best.id)
	j.reservations.append("rep:%d" % best.id)
	j.fail_key = "rep:%d" % best.id
	return j
