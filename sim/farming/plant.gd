class_name Plant
extends RefCounted
## A crop growing on one cell of a "growing" zone.

var def_id: String
var cell: Vector2i
## Growth ticks accumulated (only counted while there is enough daylight).
var growth := 0


func _init(p_def_id: String, p_cell: Vector2i) -> void:
	def_id = p_def_id
	cell = p_cell
