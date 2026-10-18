class_name MetaStore
extends RefCounted
## File IO for meta-progression (user:// is IndexedDB-backed on web).

const PATH := "user://meta.json"


static func load_state(path := PATH, defs: Defs = null) -> MetaState:
	var m := MetaState.new(defs)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return m
	var p := JSON.new()
	if p.parse(f.get_as_text()) == OK and p.data is Dictionary:
		m.load_dict(p.data)
	return m


static func save_state(m: MetaState, path := PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(m.to_dict()))
	f.close()
	return true


# region O2
const HINT_PATH := "user://hints.json"
const HINT_MODES: Array = ["Full", "New", "Off"]


## Tutorial hint density: "Full" | "New" | "Off" (default "Full").
static func load_hint_density(path := HINT_PATH) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "Full"
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary and HINT_MODES.has(str((d as Dictionary).get("density", ""))):
		return str((d as Dictionary)["density"])
	return "Full"


static func save_hint_density(mode: String, path := HINT_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"density": mode}))
	f.close()
	return true
# endregion
