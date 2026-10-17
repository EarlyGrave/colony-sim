class_name MineGiver
extends WorkGiver


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "mine"
	work_type = "mining"


func find(c: Colonist) -> Job:
	var best := JobSystem.NO_CELL
	var best_d := 1 << 30
	var m := sim.map
	for i in m.mine_designated.size():
		if m.mine_designated[i] == 0:
			continue
		var cell := Vector2i(i % m.width, i / m.width)
		var key := "dep:%d,%d" % [cell.x, cell.y]
		var d := c.cell.distance_squared_to(cell)
		if d >= best_d or not sim.jobs._free(c, key):
			continue
		if sim.pathfinder.best_adjacent(c.cell, cell).x < 0:
			continue
		best = cell
		best_d = d
	if best.x < 0:
		return null
	var j := MineJob.new(best)
	var k := "dep:%d,%d" % [best.x, best.y]
	j.reservations.append(k)
	j.fail_key = k
	return j
