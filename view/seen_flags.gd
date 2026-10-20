class_name SeenFlags
extends RefCounted
## Per-profile "already shown" flags (hints, "NEW" badges). Stable API, all static:
##   SeenFlags.seen(id) -> bool      has this id been marked?
##   SeenFlags.mark(id)              mark it (persisted to user://seen_flags.json)
##   SeenFlags.reset()               forget everything (memory + file)
## Every file access is guarded; on failure the in-memory set still works.
## Tests may point `path` at a scratch file and call reset() first.

static var path := "user://seen_flags.json"
static var _flags: Dictionary = {}
static var _loaded_path := ""


static func seen(id: String) -> bool:
	_load()
	return _flags.has(id)


static func mark(id: String) -> void:
	_load()
	if _flags.has(id):
		return
	_flags[id] = true
	_save()


static func reset() -> void:
	_flags = {}
	_loaded_path = path
	_save()


static func _load() -> void:
	if _loaded_path == path:
		return
	_loaded_path = path
	_flags = {}
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if d is Dictionary:
		for k: Variant in d:
			_flags[str(k)] = true


static func _save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_flags))
	f.close()
