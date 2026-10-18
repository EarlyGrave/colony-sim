class_name ResearchGiver
extends WorkGiver


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "research"
	work_type = "researching"


func find(c: Colonist) -> Job:
	if sim.buildings == null or ResearchOperator.active(sim) == "":
		return null
	var best: Building = null
	var best_d := 1 << 30
	for b: Building in sim.buildings.list:
		if not b.def.get("research_bench", false) or b.broken or b.destroyed:
			continue
		var key := "res:%d" % b.id
		if not sim.jobs._free(c, key) or not sim.pathfinder.reachable(c.cell, b.cell):
			continue
		var d := c.cell.distance_squared_to(b.cell)
		if d < best_d:
			best = b
			best_d = d
	if best == null:
		return null
	var j := ResearchJob.new(best.id)
	j.reservations.append("res:%d" % best.id)
	j.fail_key = "res:%d" % best.id
	return j
