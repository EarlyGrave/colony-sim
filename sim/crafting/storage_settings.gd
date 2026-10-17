class_name StorageSettings
extends RefCounted
## Per-cell storage settings: priority and item filter. Commands apply to a
## whole "zone group" (4-connected cells of the same zone type).

var sim: Simulation
## Vector2i -> {"priority": int, "blocked": {item_id: true}}; absent = defaults.
var cells: Dictionary = {}


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func priority(c: Vector2i) -> int:
	return int(cells[c]["priority"]) if cells.has(c) else int(sim.defs.crafting["default_priority"])


func accepts(c: Vector2i, item_id: String) -> bool:
	return not (cells.has(c) and cells[c]["blocked"].has(item_id))


## True if any cell deviates from the default priority (cheap pre-check).
func has_custom_priority() -> bool:
	var d := int(sim.defs.crafting["default_priority"])
	for c in cells:
		if int(cells[c]["priority"]) != d:
			return true
	return false


## Cells of the zone group containing `c`, deterministic BFS order.
func group_of(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var z := sim.map.get_zone(c)
	if z == "":
		return out
	var seen := {c: true}
	out.append(c)
	var head := 0
	while head < out.size():
		var cur := out[head]
		head += 1
		for d in MapGrid.NEIGHBORS_4:
			var nb: Vector2i = cur + d
			if not seen.has(nb) and sim.map.in_bounds(nb) and sim.map.get_zone(nb) == z:
				seen[nb] = true
				out.append(nb)
	return out


func set_filter(c: Vector2i, item_id: String, allowed: bool) -> bool:
	var z := sim.map.get_zone(c)
	if z == "" or not sim.defs.zone_accepts(z, item_id):
		return false
	for g in group_of(c):
		var e := _entry(g)
		if allowed:
			e["blocked"].erase(item_id)
		else:
			e["blocked"][item_id] = true
	sim.bus.zone_settings_changed.emit(c)
	return true


func set_priority(c: Vector2i, p: int) -> bool:
	if sim.map.get_zone(c) == "" or p < 0 or p >= sim.defs.crafting["priorities"].size():
		return false
	for g in group_of(c):
		_entry(g)["priority"] = p
	sim.bus.zone_settings_changed.emit(c)
	return true


func _entry(c: Vector2i) -> Dictionary:
	if not cells.has(c):
		cells[c] = {"priority": int(sim.defs.crafting["default_priority"]), "blocked": {}}
	return cells[c]
