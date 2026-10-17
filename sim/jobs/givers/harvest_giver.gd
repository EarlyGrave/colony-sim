class_name HarvestGiver
extends WorkGiver


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "harvest"
	work_type = "growing"


func find(c: Colonist) -> Job:
	if sim.farming == null:
		return null
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for cell: Vector2i in sim.farming.plants:
		var key := "plant:%d,%d" % [cell.x, cell.y]
		if not sim.farming.is_mature(sim.farming.plants[cell]) or not sim.jobs._free(c, key):
			continue
		var d := c.cell.distance_squared_to(cell)
		if d >= best_d or not sim.pathfinder.reachable(c.cell, cell):
			continue
		best = cell
		best_d = d
	if best.x < 0:
		return null
	var j := HarvestJob.new(best)
	j.reservations.append("plant:%d,%d" % [best.x, best.y])
	j.fail_key = "plant:%d,%d" % [best.x, best.y]
	return j
