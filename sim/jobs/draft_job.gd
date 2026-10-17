class_name DraftJob
extends Job
## A drafted colonist: ignores work and the alarm, holds position (or walks
## to the ordered cell) and fires at enemies in weapon range.


func _init() -> void:
	type = "draft"


func tick(c: Colonist, sim: Simulation) -> int:
	var cb := c.combat
	if not cb.drafted:
		return Status.DONE
	var w := sim.combat.weapon_def(c)
	var reach := float(w["range"])
	var pos := Vector2(c.cell)
	var target: Enemy = null
	if cb.target_id >= 0:
		target = sim.combat.enemy_by_id(cb.target_id)
		if target == null:
			cb.target_id = -1
	if target != null and pos.distance_to(Vector2(target.cell)) > reach:
		# Ordered attack: close the distance first.
		if c.move_toward(target.cell, sim) == GridMover.Move.FAILED:
			cb.target_id = -1
		return Status.RUNNING
	if target == null:
		var near := sim.threats.enemies_in_range(pos, reach)
		if not near.is_empty():
			target = near[0]
	if target != null:
		c.clear_path()
		sim.combat.try_attack(c, target)
		return Status.RUNNING
	if cb.order_cell.x >= 0:
		var m := c.move_toward(cb.order_cell, sim)
		if m != GridMover.Move.MOVING:
			cb.order_cell = Vector2i(-1, -1)
	return Status.RUNNING


func describe() -> String:
	return "В боевой готовности"
