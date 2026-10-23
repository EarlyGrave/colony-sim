class_name HaulJob
extends Job
## Moves items from a source (ground cell / building output / own hands) to a
## destination (storage cell / building input).

enum Src { GROUND, BUILDING_OUT, CARRIED }
enum Dst { CELL, BUILDING_IN }

var src: int
var src_cell := Vector2i(-1, -1)
var src_building := -1
var dst: int
var dst_cell := Vector2i(-1, -1)
var dst_building := -1
var item: String
var amount: int
var _picked := false


func _init() -> void:
	type = "haul"


func tick(c: Colonist, sim: Simulation) -> int:
	if not _picked:
		if src == Src.CARRIED:
			_picked = true
		else:
			var at := src_cell if src == Src.GROUND else _building_cell(sim, src_building)
			if at.x >= 0 and src == Src.BUILDING_OUT and bool(sim.defs.balance.get("haul_blocked_fix", false)) and not sim.pathfinder.is_walkable(at):
				at = sim.pathfinder.best_adjacent(c.cell, at)  # CU: a rock-bound miner is emptied from a neighbour cell
			if at.x < 0:
				return Status.FAILED
			var m := c.move_toward(at, sim)
			if m == GridMover.Move.FAILED:
				return Status.FAILED
			if m == GridMover.Move.MOVING:
				return Status.RUNNING
			if not _pick_up(c, sim):
				return Status.FAILED
			_picked = true
			return Status.RUNNING

	var to := dst_cell if dst == Dst.CELL else _building_cell(sim, dst_building)
	if to.x < 0:
		return Status.FAILED
	var mv := c.move_toward(to, sim)
	if mv == GridMover.Move.FAILED:
		return Status.FAILED
	if mv == GridMover.Move.MOVING:
		return Status.RUNNING
	_deliver(c, sim)
	return Status.DONE


func _pick_up(c: Colonist, sim: Simulation) -> bool:
	var want := amount
	if c.carry_count > 0 and c.carry_item != item:
		return false
	var q := ""
	var cap := sim.traits.carry_cap(c, int(sim.defs.balance["colonist"]["carry_capacity"])) - c.carry_count  # region traits
	if sim.passives.rule(c, "unlimited_carry"):  # region F11W3
		cap = 1 << 30
	want = mini(want, cap)
	var got := 0
	if src == Src.GROUND:
		if sim.items.item_at(src_cell) != item:
			return false
		q = sim.items.quality_at(src_cell)
		if c.carry_count > 0 and c.carry_quality != q:
			return false
		got = sim.items.take_at(src_cell, want)
	else:
		var b: Building = sim.buildings.get_by_id(src_building)
		if b == null:
			return false
		var run := b.next_run(item, want)
		q = str(run["q"])
		if c.carry_count > 0 and c.carry_quality != q:
			return false
		got = b.take_output(item, mini(want, int(run["count"])))
	if got <= 0:
		return false
	c.carry_item = item
	c.carry_quality = q
	c.carry_count += got
	return true


func _deliver(c: Colonist, sim: Simulation) -> void:
	if c.carry_count <= 0:
		return
	var put := 0
	if dst == Dst.CELL:
		put = sim.items.add_at(dst_cell, c.carry_item, c.carry_count, c.carry_quality)
	else:
		var b: Building = sim.buildings.get_by_id(dst_building)
		if b != null:
			put = b.add_input(c.carry_item, c.carry_count)
	c.carry_count -= put
	if c.carry_count <= 0:
		c.carry_item = ""
		c.carry_count = 0


func _building_cell(sim: Simulation, id: int) -> Vector2i:
	var b: Building = sim.buildings.get_by_id(id) if sim.buildings else null
	return b.cell if b != null else Vector2i(-1, -1)


func describe() -> String:
	return "Hauling: " + item
