class_name RepairJob
extends Job
## Walk to a damaged / worn / broken building (or a damaged belt tile) and fix it.

var building_id: int
var belt_cell := Vector2i(-1, -1)  # region T3: set for belt-tile repairs (building_id = -1)
var _work := 0.0


func _init(p_id: int) -> void:
	type = "repair"
	building_id = p_id


# region T3
static func for_belt(c: Vector2i) -> RepairJob:
	var j := RepairJob.new(-1)
	j.belt_cell = c
	return j


func _tick_belt(c: Colonist, sim: Simulation) -> int:
	if not sim.logistics.belt_needs_repair(belt_cell):
		return Status.DONE
	var m := c.move_toward(belt_cell, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	_work += sim.jobs.work_tick(c, "repair")
	if _work < int(sim.defs.balance["line_damage"]["repair_ticks"]):
		return Status.RUNNING
	return Status.DONE if sim.logistics.repair_belt(belt_cell) else Status.FAILED
# endregion


func tick(c: Colonist, sim: Simulation) -> int:
	if building_id < 0:  # region T3
		return _tick_belt(c, sim)
	var b := sim.buildings.get_by_id(building_id)
	if b == null or not b.needs_repair(sim):
		return Status.DONE
	var m := c.move_toward(b.cell, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	_work += sim.jobs.work_tick(c, "repair")
	if _work < int(sim.defs.balance["repair"]["work_ticks"]):
		return Status.RUNNING
	# region T3: structural damage costs materials (data: line_damage); wear-only repair stays free
	if b.hp < b.max_hp and not sim.buildings.pay_repair(sim.buildings.repair_cost_of(b), b.cell):
		return Status.FAILED
	# endregion
	sim.buildings.repair(b)
	return Status.DONE


func describe() -> String:
	return "Repairing"
