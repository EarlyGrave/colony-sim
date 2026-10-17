class_name OperateGiver
extends WorkGiver


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "operate"
	work_type = "operating"


func find(c: Colonist) -> Job:
	if sim.buildings == null:
		return null
	var best: Building = null
	var best_d := 1 << 30
	for b: Building in sim.buildings.list:
		var key := "op:%d" % b.id
		if not b.can_run_recipe() or not sim.jobs._free(c, key) or not sim.pathfinder.reachable(c.cell, b.cell):
			continue
		var d := c.cell.distance_squared_to(b.cell)
		if d < best_d:
			best = b
			best_d = d
	if best == null:
		return null
	var j := OperateJob.new(best.id)
	j.reservations.append("op:%d" % best.id)
	j.fail_key = "op:%d" % best.id
	return j
