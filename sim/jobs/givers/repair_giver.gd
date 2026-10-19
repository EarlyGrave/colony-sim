class_name RepairGiver
extends WorkGiver


func _init(p_sim: Simulation) -> void:
	super(p_sim)
	id = "repair"
	work_type = "repair"


func find(c: Colonist) -> Job:
	if sim.buildings == null:
		return null
	var mode := sim.get_rule_mode("repair_priority")  # region T3
	var best: Building = null
	var rock_fix := bool(sim.defs.balance.get("repair_rock_fix", false))  # RP: measured worse for survival/audit (chaotic), off by default
	var best_d := 1 << 30
	var best_pri := -1
	for b: Building in sim.buildings.list:
		var key := "rep:%d" % b.id
		if not b.needs_repair(sim) or not sim.jobs._free(c, key) or not (sim.pathfinder.can_approach(c.cell, b.cell) if rock_fix else sim.pathfinder.reachable(c.cell, b.cell)):  # RP: miners on rock node cells are not walkable, so reachable() hid them forever
			continue
		if b.hp < b.max_hp and not _affordable(sim.buildings.repair_cost_of(b)):  # region T3
			continue
		var pri := 0 if mode != "turrets" or not b.def.has("turret") else 1  # region T3
		if mode == "machines" and b.is_machine():
			pri = 1
		var d := c.cell.distance_squared_to(b.cell)
		if pri > best_pri or (pri == best_pri and d < best_d):
			best = b
			best_d = d
			best_pri = pri
	var belt := _find_belt(c, mode)  # region T3
	if belt.x >= 0 and (best == null or mode == "belts" or best_d > c.cell.distance_squared_to(belt) and best_pri == 0):
		var jb := RepairJob.for_belt(belt)
		jb.reservations.append("rep:belt:%d,%d" % [belt.x, belt.y])
		jb.fail_key = jb.reservations[0]
		return jb
	if best == null:
		return null
	var j := RepairJob.new(best.id)
	j.reservations.append("rep:%d" % best.id)
	j.fail_key = "rep:%d" % best.id
	return j


# region T3
func _affordable(cost: Dictionary) -> bool:
	for item: String in cost:
		if sim.items.count_stored(item) < int(cost[item]):
			return false
	return true


## Nearest damaged belt tile (scan is bounded by the damaged set, not the map).
func _find_belt(c: Colonist, _mode: String) -> Vector2i:
	var belts := sim.logistics.belts
	if belts.hp_damaged.is_empty() or not _affordable(sim.defs.balance["line_damage"]["belt_repair_cost"]):
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for i: int in belts.hp_damaged:
		var cell := Vector2i(i % belts.width, i / belts.width)
		if not belts.is_damaged(cell) or not sim.jobs._free(c, "rep:belt:%d,%d" % [cell.x, cell.y]) \
				or not sim.pathfinder.reachable(c.cell, cell):
			continue
		var d := c.cell.distance_squared_to(cell)
		if d < best_d or (d == best_d and i < best.y * belts.width + best.x):
			best = cell
			best_d = d
	return best
# endregion
