class_name TendGiver
extends WorkGiver
## Tends colonists with untended injuries. Self-tending (lower quality) only
## when nobody else is able to doctor and the patient is not downed.


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "tend"
	work_type = "doctoring"


static func has_untended(p: Colonist) -> bool:
	if p.health == null:
		return false
	for i in p.health.injuries:
		if not i.tended:
			return true
	return false


func find(c: Colonist) -> Job:
	var best: Colonist = null
	var best_d := 1 << 30
	for p in sim.colonists.list:
		var key := "tend:%d" % p.id
		if not p.alive or p.hidden or p.health == null or p.health.carrier_id >= 0 or not has_untended(p):
			continue
		if not sim.jobs._free(c, key):
			continue
		if p == c and (p.health.downed or _other_doctor_exists(c)):
			continue
		if not sim.pathfinder.reachable(c.cell, p.cell):
			continue
		var d := c.cell.distance_squared_to(p.cell)
		if p.health.bleed_rate() > 0.0:
			d -= 1 << 20  # bleeding patients first
		if d < best_d:
			best = p
			best_d = d
	if best == null:
		return null
	var j := TendJob.new(best.id)
	j.reservations.append("tend:%d" % best.id)
	j.fail_key = "tend:%d" % best.id
	return j


func _other_doctor_exists(c: Colonist) -> bool:
	for o in sim.colonists.list:
		if o != c and o.alive and not o.hidden and not o.is_sick(sim.tick) \
				and (o.health == null or not o.health.downed) and o.skills.priority("doctoring") > 0:
			return true
	return false
