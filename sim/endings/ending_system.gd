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
	var ep := epilogue_for(id, sim)  # region RV
	if not ep.is_empty():
		sim.bus.letter_received.emit(str(ep[0]), "\n".join(PackedStringArray(ep.slice(1))))
	return true


# region F9W2
## Promised path effects (data/endings.json "path_effects"). Returns `default` while no path is chosen
## or the key is absent for it. Callers compose with quest mods as a PRODUCT (grace_days: sum).
func effect(name: String, default: float) -> float:
	var p := path()
	if p == "":
		return default
	var e: Dictionary = (sim.defs.endings.get("path_effects", {}) as Dictionary).get(p, {})
	return float(e.get(name, default))
# endregion


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


# region F6c
## Base epilogue + one echo line per set r4 quest flag + a masterwork line (up to 2 names).
static func epilogue_for(id: String, sim: Simulation) -> Array:
	var ep := epilogue(id).duplicate()
	if ep.is_empty() or sim == null:
		return ep
	for l: String in echo_lines(id, sim):
		ep.append(l)
	return ep


static func echo_lines(id: String, sim: Simulation) -> Array:
	var out: Array = []
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/flavor.json"))
	if j is Dictionary and sim != null and sim.quests != null:
		for e: Variant in (j as Dictionary).get("epilogue_echo", {}).get(id, []):
			if sim.quests.flag(str((e as Dictionary).get("flag", ""))):
				out.append(str((e as Dictionary)["line"]))
	if sim != null and sim.fixation != null and not sim.fixation.masterworks.is_empty():
		var names: Array = []
		for m: Dictionary in sim.fixation.masterworks.slice(0, 2):
			names.append(str(m["name"]))
		out.append("Hung on the wall: %s." % ", ".join(PackedStringArray(names)))
	return out
# endregion
