class_name LogisticsStub
extends RefCounted
## TEMPORARY STUB (worker A1d). Replace with A1c's sim/logistics/logistics_system.gd.
## Only stores belt cells -> direction (0=E,1=S,2=W,3=N). No item movement.
## Interface used by Simulation region A1d: place_path, remove_at, set_dir, has_belt, dir_at, state_parts.

var dirs: Dictionary = {}  # Vector2i -> int


func _init(_sim: Object = null) -> void:
	pass


func place_path(cells: Array, p_dirs: Array) -> void:
	for i in cells.size():
		dirs[cells[i]] = int(p_dirs[i])


func remove_at(cell: Vector2i) -> bool:
	return dirs.erase(cell)


func set_dir(cell: Vector2i, dir: int) -> bool:
	if not dirs.has(cell):
		return false
	dirs[cell] = dir
	return true


func has_belt(cell: Vector2i) -> bool:
	return dirs.has(cell)


func dir_at(cell: Vector2i) -> int:
	return int(dirs.get(cell, -1))


## Deterministic (sorted) snapshot for SaveGame.state_hash.
func state_parts() -> Array:
	var keys: Array = dirs.keys()
	keys.sort()
	var out: Array = []
	for k: Vector2i in keys:
		out.append([k, dirs[k]])
	return out
