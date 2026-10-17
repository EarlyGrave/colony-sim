class_name ScrubGiver
extends WorkGiver
## Low-priority cleanup: scrub waste lying near the base.


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "scrub"
	work_type = "cleanup"


func find(c: Colonist) -> Job:
	if sim.alarm or not sim.idle_work.can_scrub():
		return null
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for cell in sim.idle_work.scrub_cells():
		var key := "scrub:%d,%d" % [cell.x, cell.y]
		var d := c.cell.distance_squared_to(cell)
		if d >= best_d or not sim.jobs._free(c, key) or not sim.pathfinder.reachable(c.cell, cell):
			continue
		best = cell
		best_d = d
	if best.x < 0:
		return null
	var key := "scrub:%d,%d" % [best.x, best.y]
	var job := ScrubJob.new(best)
	job.reservations.append(key)
	job.fail_key = key
	return job
