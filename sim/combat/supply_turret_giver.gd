class_name SupplyTurretGiver
extends WorkGiver
## Hauls rounds from storage into turrets that are running low.


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "supply_turret"
	work_type = "hauling"


func find(c: Colonist) -> Job:
	if sim.ammo == null or sim.buildings == null:
		return null
	var js := sim.jobs
	var best: Job = null
	var best_d := 1 << 30
	for b: Building in sim.buildings.list:
		var key := "ammo:%d" % b.id
		if not sim.ammo.turret_wants_refill(b) or not js._free(c, key) or not sim.pathfinder.reachable(c.cell, b.cell):
			continue
		for cell: Vector2i in sim.items.stacks:
			var ckey := "cell:%d,%d" % [cell.x, cell.y]
			if sim.items.item_at(cell) != sim.ammo.item or not sim.items.is_stored(cell) \
					or not js._free(c, ckey) or not sim.pathfinder.reachable(c.cell, cell):
				continue
			var d := c.cell.distance_squared_to(cell) + c.cell.distance_squared_to(b.cell)
			if d >= best_d:
				continue
			var n := mini(sim.ammo.turret_missing(b), sim.items.count_at(cell))
			var j := SupplyTurretJob.new(b.id, cell, n)
			j.reservations.append(key)
			j.reservations.append(ckey)
			j.fail_key = key
			best = j
			best_d = d
	return best
