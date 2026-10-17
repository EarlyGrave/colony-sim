class_name SaveStore
extends RefCounted
## File IO for saves. user:// is IndexedDB-backed on web.

const PATH := "user://autosave.json"


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


static func write(sim: Simulation, path := PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(SaveGame.to_json(sim))
	f.close()
	return true


static func read_text(path := PATH) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()
