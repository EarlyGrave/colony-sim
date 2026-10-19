class_name Enemy
extends GridMover
## A creature. Targets key buildings and colonists in the open.

enum Target { NONE, BUILDING, COLONIST, BELT }  # BELT (R3X): target_cell is a belt tile

var id: int
var def_id: String
var def: Dictionary
var hp: float
var max_hp: float
var spawn_cell: Vector2i
var target_kind := Target.NONE
var target_id := -1
## Belt tile when target_kind == BELT (target_id = threat region key).
var target_cell := Vector2i(-1, -1)  # region R3X
var retarget_at := 0
# region perf-threat
var target_b: Building
var target_c: Colonist
var attack_range := 1.5
# endregion
var attack_cd := 0
# region W2d: hot-loop data kept as plain typed fields (no meta / Dictionary lookups per tick)
var winding := false  ## C3 wind-up active (mirrors meta "tg")
var bite_at := 0  ## tick the next belt bite may happen
var structure_dmg := 0.0  ## def.structure_dmg
var cd_ticks := 0  ## def.attack_cooldown_ticks
var pk_gen := -1  ## ThreatModel.pick memo: generation, cell and sticky-target fingerprint of the stored result
var pk_cell := Vector2i(-1, -1)
var pk_tk := 0
var pk_tid := -1
var pk_tcell := Vector2i(-1, -1)
var pk_res: Dictionary = {}
var rc_cell := Vector2i(-1, -1)  ## range-check memo: building target in range from rc_cell
var rc_b: Building
var rc_in := false
var pk_s := 0.0
var pk_bias := PackedFloat64Array()
var pk_bld: Building  ## building the memoised result / sticky target depends on
# endregion
## Mutant variant id ("" = plain), rolled from nest pollution (T5).
var variant := ""  # region T5
var damage_mult := 1.0  # region T5
# region E1
var att_stats := StatBlock.make()  ## attack side (crit/pen), defaults for now
var def_stats := StatBlock.make()  ## armour/flat from def.armor / def.flat
# endregion
## After the wave ends survivors walk back to the edge and vanish.
var leaving := false


func _init(p_id: int, p_def_id: String, p_def: Dictionary, p_cell: Vector2i) -> void:
	id = p_id
	def_id = p_def_id
	def = p_def
	cell = p_cell
	spawn_cell = p_cell
	max_hp = float(def["max_hp"])
	hp = max_hp
	move_ticks = int(def["move_ticks"])
	attack_range = float(def["attack_range"])  # region perf-threat
	structure_dmg = float(def.get("structure_dmg", 0.0))  # region W2d
	cd_ticks = int(def.get("attack_cooldown_ticks", 0))
	# region E1
	var ar: Dictionary = def.get("armor", {})
	var fl: Dictionary = def.get("flat", {})
	def_stats[StatBlock.ARM_PHYS] = float(ar.get("phys", 0.0))
	def_stats[StatBlock.ARM_ENERGY] = float(ar.get("energy", 0.0))
	def_stats[StatBlock.FLAT_PHYS] = float(fl.get("phys", 0.0))
	def_stats[StatBlock.FLAT_ENERGY] = float(fl.get("energy", 0.0))
	# endregion


## GridMover.move_flow without the speed-bonus calls: enemies have none (move_gain is always 1.0), so the
## per-tick `_bonus_steps` / `move_gain` / `is_equal_approx` chain only ever returned 0.
func move_flow(field: FlowField, sim: Simulation) -> int:
	if path.is_empty():
		var dc := field.dist_at(cell)
		if dc == 0:
			clear_path()
			return Move.ARRIVED
		if not field.complete and dc < 0:
			return Move.MOVING  # the search has not reached us yet
		var n := field.next_step_from(cell, dc, sim.pathfinder.walk_grid())  # region E5
		if n.x < 0:
			return Move.FAILED
		path.append(n)
	move_t += 1
	if move_t < move_ticks:
		return Move.MOVING
	move_t = 0
	var next: Vector2i = path[0]
	path.clear()
	if not sim.pathfinder.is_walkable(next):
		return Move.MOVING  # the field is stale; the next tick picks a fresh step
	cell = next
	if field.dist_at(cell) == 0:
		return Move.ARRIVED
	return Move.MOVING
