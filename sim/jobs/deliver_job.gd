class_name DeliverJob
extends Job
## Carries construction materials from a stored stack into a blueprint.

var blueprint_id: int
var src_cell: Vector2i
var item: String
var amount: int
var _picked := false


func _init(p_bp: int, p_src: Vector2i, p_item: String, p_amount: int) -> void:
	type = "deliver"
	blueprint_id = p_bp
	src_cell = p_src
	item = p_item
	amount = p_amount


func tick(c: Colonist, sim: Simulation) -> int:
	var bp := sim.buildings.get_blueprint(blueprint_id)
	if bp == null:
		return Status.FAILED if not _picked else Status.DONE  # leftovers are re-routed by JobSystem.assign
	if not _picked:
		var m := c.move_toward(src_cell, sim)
		if m == GridMover.Move.FAILED:
			return Status.FAILED
		if m == GridMover.Move.MOVING:
			return Status.RUNNING
		if c.carry_count > 0 and c.carry_item != item:
			return Status.FAILED
		var want := mini(mini(amount, bp.missing(item)), int(sim.defs.balance["colonist"]["carry_capacity"]) - c.carry_count)
		if sim.items.item_at(src_cell) != item or want <= 0:
			return Status.FAILED
		var got := sim.items.take_at(src_cell, want)
		if got <= 0:
			return Status.FAILED
		c.carry_item = item
		c.carry_count += got
		_picked = true
		return Status.RUNNING
	var stand := sim.buildings.bp_stand(bp, c.cell)
	if stand.x < 0:
		return Status.FAILED
	var mv := c.move_toward(stand, sim)
	if mv == GridMover.Move.FAILED:
		return Status.FAILED
	if mv == GridMover.Move.MOVING:
		return Status.RUNNING
	var put := mini(c.carry_count, bp.missing(c.carry_item))
	if put > 0:
		bp.delivered[c.carry_item] = int(bp.delivered.get(c.carry_item, 0)) + put
		c.carry_count -= put
		if c.carry_count <= 0:
			c.carry_item = ""
			c.carry_count = 0
		sim.bus.blueprint_progress.emit(bp.id)
	return Status.DONE


func describe() -> String:
	return "Delivering materials"
