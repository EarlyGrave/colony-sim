class_name OperateGiver
extends WorkGiver


## `p_id` / `p_type`: other givers of this class serve other work types
## (e.g. "cook" for cooking); buildings pick theirs with def "work_type".
func _init(p_sim: Simulation, p_id := "operate", p_type := "operating") -> void:
	super(p_sim)
	id = p_id
	work_type = p_type


func find(c: Colonist) -> Job:
	if sim.buildings == null:
		return null
	var best: Building = null
	var best_d := 1 << 30
	# region F11W3: Clean Hands never refines; Slow Hands strikes while the planet is > 50 % contaminated
	var no_refine := sim.passives.rule(c, "no_refinery")
	var strike := sim.passives.rule(c, "refine_strike") and sim.contamination.fraction() > 0.5
	var ess := sim.passives.rule(c, "essence_craft")
	# endregion
	for b: Building in sim.buildings.list:
		var key := "op:%d" % b.id
		if str(b.def.get("work_type", "operating")) != work_type:
			continue
		if (no_refine or strike) and sim.buildings._is_refining(b):  # region F11W3
			continue
		if ess and sim.buildings.craft_refused_for(b, c):  # region F11W3 (essence_craft without stored essence_ore)
			continue
		if not sim.buildings.may_operate(b) or not sim.jobs._free(c, key) or not sim.pathfinder.reachable(c.cell, b.cell):
			continue
		var d := c.cell.distance_squared_to(b.cell)
		if d < best_d:
			best = b
			best_d = d
	if best == null:
		return null
	var j := OperateJob.new(best.id)
	j.work_type = work_type
	j.reservations.append("op:%d" % best.id)
	j.fail_key = "op:%d" % best.id
	return j
