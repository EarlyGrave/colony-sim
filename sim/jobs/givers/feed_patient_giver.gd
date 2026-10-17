class_name FeedPatientGiver
extends WorkGiver
## Hungry downed patients cannot eat on their own: bring them food.


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "feed_patient"
	work_type = "doctoring"


func find(c: Colonist) -> Job:
	var thr := float(sim.defs.needs["food"]["eat_threshold"])
	var best: Colonist = null
	var best_d := 1 << 30
	for p in sim.colonists.list:
		var key := "feed:%d" % p.id
		if p == c or not p.alive or p.health == null or not p.health.downed or p.health.carrier_id >= 0:
			continue
		if sim.needs.state_of(p).food >= thr or not sim.jobs._free(c, key):
			continue
		if not sim.pathfinder.reachable(c.cell, p.cell):
			continue
		var d := c.cell.distance_squared_to(p.cell)
		if d < best_d:
			best = p
			best_d = d
	if best == null:
		return null
	var food := _food_cell(c, best)
	if food.x < 0:
		return null
	var j := FeedPatientJob.new(best.id, food)
	j.reservations.append("feed:%d" % best.id)
	j.fail_key = "feed:%d" % best.id
	return j


## Best stored food (highest nutrition, then nearest to the doctor).
func _food_cell(c: Colonist, patient: Colonist) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_nut := -1.0
	var best_d := 1 << 30
	for cell: Vector2i in sim.items.stacks:
		var item: String = sim.items.stacks[cell]["item"]
		if not sim.defs.items[item].has("nutrition") or not sim.items.is_stored(cell):
			continue
		var nut := float(sim.defs.items[item]["nutrition"])
		var d := c.cell.distance_squared_to(cell)
		if nut < best_nut or (nut == best_nut and d >= best_d):
			continue
		if not sim.pathfinder.reachable(c.cell, cell) or not sim.pathfinder.reachable(cell, patient.cell):
			continue
		best = cell
		best_nut = nut
		best_d = d
	return best
