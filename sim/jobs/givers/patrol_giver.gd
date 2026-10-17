class_name PatrolGiver
extends WorkGiver
## Low-priority patrol along the (auto or player-set) route. One patrol at a time.

const KEY := "patrol"


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "patrol"
	work_type = "patrol"


func find(c: Colonist) -> Job:
	if sim.alarm or not sim.idle_work.patrol_ready(c) or not sim.jobs._free(c, KEY):
		return null
	var pts := sim.idle_work.route()
	if pts.is_empty():
		return null
	# Start at the nearest point so the walk begins close to the colonist.
	var start := 0
	var best_d := 1 << 30
	for i in pts.size():
		var d := c.cell.distance_squared_to(pts[i])
		if d < best_d and sim.pathfinder.reachable(c.cell, pts[i]):
			start = i
			best_d = d
	if best_d == 1 << 30:
		return null
	var job := PatrolJob.new(pts.duplicate(), start, int(sim.defs.idle_work["patrol"]["legs_per_job"]))
	job.reservations.append(KEY)
	return job
