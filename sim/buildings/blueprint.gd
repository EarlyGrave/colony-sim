class_name Blueprint
extends RefCounted
## A planned building (RimWorld "frame"): colonists haul the cost items into it,
## then build it. Materials are consumed only when construction completes.

var id: int
var def_id: String
var def: Dictionary
var cell: Vector2i  # top-left
var size: Vector2i
## item -> count already delivered
var delivered: Dictionary = {}
## Build work done so far (skill-scaled ticks).
var work_done := 0.0
var work_total: float


func _init(p_id: int, p_def_id: String, p_def: Dictionary, p_cell: Vector2i, default_work: float) -> void:
	id = p_id
	def_id = p_def_id
	def = p_def
	cell = p_cell
	size = Vector2i(int(def["size"][0]), int(def["size"][1]))
	work_total = float(def.get("build_work", default_work))


func footprint() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			out.append(cell + Vector2i(x, y))
	return out


func contains(c: Vector2i) -> bool:
	return c.x >= cell.x and c.y >= cell.y and c.x < cell.x + size.x and c.y < cell.y + size.y


func missing(item: String) -> int:
	return int(def["cost"][item]) - int(delivered.get(item, 0))


func has_all_materials() -> bool:
	for item: String in def["cost"]:
		if missing(item) > 0:
			return false
	return true


func delivered_total() -> int:
	var s := 0
	for k: String in delivered:
		s += int(delivered[k])
	return s


func progress_fraction() -> float:
	return clampf(work_done / maxf(work_total, 1.0), 0.0, 1.0)
