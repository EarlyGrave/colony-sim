class_name RescueGiver
extends WorkGiver
## A downed colonist outside a bed is carried to the nearest free bed
## (or a shelter such as the capsule when no bed exists).


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "rescue"
	work_type = "doctoring"


func find(c: Colonist) -> Job:
	var best: Colonist = null
	var best_d := 1 << 30
	for p in sim.colonists.list:
		var key := "resc:%d" % p.id
		if p == c or not p.alive or p.health == null or not p.health.downed or p.health.bed_id >= 0 \
				or p.health.carrier_id >= 0 or p.hidden or not sim.jobs._free(c, key):
			continue
		if not sim.pathfinder.reachable(c.cell, p.cell):
			continue
		var d := c.cell.distance_squared_to(p.cell)
		if d < best_d:
			best = p
			best_d = d
	if best == null:
		return null
	var bed := find_bed(best, c)
	if bed == null:
		return null
	var j := RescueJob.new(best.id, bed.id)
	j.reservations.append("resc:%d" % best.id)
	j.reservations.append("bed:%d" % bed.id)
	j.fail_key = "resc:%d" % best.id
	return j


## Nearest free, reachable bed to the patient; else the nearest shelter.
func find_bed(patient: Colonist, rescuer: Colonist) -> Building:
	var best: Building = null
	var best_d := 1 << 30
	for b: Building in sim.buildings.list:
		if not b.def.get("bed", false) or not sim.jobs._free(rescuer, "bed:%d" % b.id) or sim.health.bed_occupied(b.id):
			continue
		if not sim.pathfinder.reachable(patient.cell, b.cell):
			continue
		var d := patient.cell.distance_squared_to(b.cell)
		if d < best_d:
			best = b
			best_d = d
	if best != null:
		return best
	return sim.buildings.find_shelter(patient.cell)
