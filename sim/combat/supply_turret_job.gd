class_name SupplyTurretJob
extends Job
## Carries rounds from a stored stack into a turret's ammo buffer.

var building_id: int
var src_cell: Vector2i
var amount: int
var _picked := false


func _init(p_building: int, p_src: Vector2i, p_amount: int) -> void:
	type = "supply_turret"
	building_id = p_building
	src_cell = p_src
	amount = p_amount


func tick(c: Colonist, sim: Simulation) -> int:
	var b := sim.buildings.get_by_id(building_id)
	if b == null or b.destroyed:
		return Status.FAILED if not _picked else Status.DONE
	if not _picked:
		var m := c.move_toward(src_cell, sim)
		if m == GridMover.Move.FAILED:
			return Status.FAILED
		if m == GridMover.Move.MOVING:
			return Status.RUNNING
		var item := sim.ammo.item
		var room := int(sim.defs.balance["colonist"]["carry_capacity"]) - c.carry_count
		var want := mini(mini(amount, sim.ammo.turret_missing(b)), room)
		if sim.items.item_at(src_cell) != item or want <= 0 or (c.carry_count > 0 and c.carry_item != item):
			return Status.FAILED
		var got := sim.items.take_at(src_cell, want)
		if got <= 0:
			return Status.FAILED
		c.carry_item = item
		c.carry_count += got
		_picked = true
		return Status.RUNNING
	var mv := c.move_toward(b.cell, sim)
	if mv == GridMover.Move.FAILED:
		return Status.FAILED
	if mv == GridMover.Move.MOVING:
		return Status.RUNNING
	if c.carry_item == sim.ammo.item:
		c.carry_count -= sim.ammo.load_turret(b, c.carry_count)
		if c.carry_count <= 0:
			c.carry_item = ""
			c.carry_count = 0
	return Status.DONE


func describe() -> String:
	return "Loading a turret"
