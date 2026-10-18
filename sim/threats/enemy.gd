class_name Enemy
extends GridMover
## A creature. Targets key buildings and colonists in the open.

enum Target { NONE, BUILDING, COLONIST }

var id: int
var def_id: String
var def: Dictionary
var hp: float
var max_hp: float
var spawn_cell: Vector2i
var target_kind := Target.NONE
var target_id := -1
var retarget_at := 0
# region perf-threat
var target_b: Building
var target_c: Colonist
var attack_range := 1.5
# endregion
var attack_cd := 0
## Mutant variant id ("" = plain), rolled from nest pollution (T5).
var variant := ""  # region T5
var damage_mult := 1.0  # region T5
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
