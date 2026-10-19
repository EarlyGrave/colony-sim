class_name EndingSystem
extends RefCounted
## EN1: the chosen path (set by quest Q14 flag `path_<id>`), its point of no return and ending_won.
## State lives in QuestLog flags (saved + hashed there), so this class holds none.

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func path_ids() -> Array:
	return sim.defs.endings.get("paths", [])


## Chosen path id, or "" before the truth beat (then every system behaves as before).
func path() -> String:
	for id: String in path_ids():
		if sim.quests.flag("path_" + id):
			return id
	return ""


## Choose / change a path. Refused for unknown ids and once the path is locked.
func set_path(id: String) -> bool:
	if id not in path_ids() or is_locked():
		return false
	for other: String in path_ids():
		sim.quests.flags.erase("path_" + other)
	sim.quests.set_flag("path_" + id)
	return true


## Has the current path passed its point of no return? Submit: first petition delivered.
func is_locked() -> bool:
	var p := path()
	if p == "":
		return false
	if p == "submit":
		return sim.petition.is_done(int(sim.defs.endings.get("submit_ponr_petition_phase", 1)))
	var f: String = str((sim.defs.endings.get("ponr_flags", {}) as Dictionary).get(p, ""))
	return f != "" and sim.quests.flag(f)


## Petitions are the jailers' deal: refused once a non-submit path is locked.
func petition_allowed() -> bool:
	var p := path()
	return p == "" or p == "submit" or not is_locked()


## Recipes with "requires_tech" run only after that tech is researched (even when research gating is off).
func tech_ok(recipe_id: String) -> bool:
	var t: String = str(sim.defs.recipes.get(recipe_id, {}).get("requires_tech", ""))
	return t == "" or sim.research.is_done(t)


func won(id: String) -> bool:
	return sim.quests.flag("ending_won_" + id)


func mark_won(id: String) -> bool:
	if id not in path_ids() or won(id):
		return false
	sim.quests.set_flag("ending_won_" + id)
	sim.bus.ending_won.emit(id)
	var ep := epilogue(id)  # region RV
	if not ep.is_empty():
		sim.bus.letter_received.emit(str(ep[0]), "\n".join(PackedStringArray(ep.slice(1))))
	return true


# region RV
## Epilogue lines for an ending ([title, line, ...]) from data/flavor.json "epilogue"; empty if missing.
static func epilogue(id: String) -> Array:
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/flavor.json"))
	if j is Dictionary:
		var a: Variant = (j as Dictionary).get("epilogue", {}).get(id, [])
		if a is Array:
			return a
	return []
# endregion
