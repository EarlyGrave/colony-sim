class_name BuildGiver
extends WorkGiver
## Builds blueprints whose materials are all delivered.


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "build"
	work_type = "construction"


func find(c: Colonist) -> Job:
	var best: Blueprint = null
	var best_d := 1 << 30
	for bp: Blueprint in sim.buildings.blueprints:
		var key := "bp:%d" % bp.id
		if not bp.has_all_materials() or not sim.jobs._free(c, key) or not sim.pathfinder.reachable(c.cell, bp.cell):
			continue
		var d := c.cell.distance_squared_to(bp.cell)
		if d < best_d:
			best = bp
			best_d = d
	if best == null:
		return null
	var j := BuildJob.new(best.id)
	j.reservations.append("bp:%d" % best.id)
	j.fail_key = "bp:%d" % best.id
	return j
