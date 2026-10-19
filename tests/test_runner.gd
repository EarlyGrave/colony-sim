extends Node
## Minimal headless test runner.
##
## Usage: godot --headless --path . res://tests/run_tests.tscn [-- --filter=substr] [--shard=i/n]
## --shard=i/n (1-based) runs one balanced slice of the suite (greedy by tests/shard_weights.json, ms per test);
## tools/run_tests_sharded.sh starts all n shards in parallel.
## Finds res://tests/test_*.gd, runs every `test_*` method, exits with code 1
## on any failure.


## Collects engine/script errors so a test that crashes counts as failed.
class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append("%s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function])
		_mutex.unlock()

	func take() -> Array[String]:
		_mutex.lock()
		var out := errors.duplicate()
		errors.clear()
		_mutex.unlock()
		return out


var _catcher := ErrorCatcher.new()


func _ready() -> void:
	OS.add_logger(_catcher)
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	var shard := Vector2i(1, 1)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shard="):
			var p := arg.trim_prefix("--shard=").split("/")
			shard = Vector2i(int(p[0]), int(p[1]))
	var code := run_all(filter, shard)
	get_tree().quit(code)


## Greedy longest-first assignment of tests to shards; deterministic (same input, same slices).
func _shard_set(names: Array[String], shard: Vector2i) -> Dictionary:
	var weights: Dictionary = {}
	var f := FileAccess.open("res://tests/shard_weights.json", FileAccess.READ)
	if f != null:
		weights = JSON.parse_string(f.get_as_text())
	var order := names.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool:
		var wa := int(weights.get(a, 300))
		var wb := int(weights.get(b, 300))
		return wa > wb if wa != wb else a < b)
	var load_ms: Array[int] = []
	load_ms.resize(shard.y)
	load_ms.fill(0)
	var mine: Dictionary = {}
	for n in order:
		var best := 0
		for i in shard.y:
			if load_ms[i] < load_ms[best]:
				best = i
		load_ms[best] += int(weights.get(n, 300))
		if best == shard.x - 1:
			mine[n] = true
	return mine


## `--filter=a,b` runs tests whose "file::method" contains any of the comma-separated parts.
func _matches(full: String, filter: String) -> bool:
	for part in filter.split(","):
		if part != "" and full.contains(part):
			return true
	return false


func run_all(filter: String, shard := Vector2i(1, 1)) -> int:
	var files: Array[String] = []
	var dir := DirAccess.open("res://tests")
	for f in dir.get_files():
		var name := f.trim_suffix(".remap")
		if name.begins_with("test_") and name.ends_with(".gd") and name != "test_case.gd" and name != "test_runner.gd":
			files.append(name)
	files.sort()

	var all_names: Array[String] = []
	if shard.y > 1:
		for f in files:
			var sc: GDScript = load("res://tests/" + f)
			if sc != null and sc.can_instantiate():
				for m in sc.get_script_method_list():
					if str(m["name"]).begins_with("test_"):
						all_names.append("%s::%s" % [f.get_basename(), m["name"]])
	var mine := _shard_set(all_names, shard) if shard.y > 1 else {}
	var passed := 0
	var failed := 0
	var started := Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			failed += 1
			print("  FAIL  %s: script does not compile" % f)
			continue
		for m in script.get_script_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			var full := "%s::%s" % [f.get_basename(), mname]
			if filter != "" and not _matches(full, filter):
				continue
			if shard.y > 1 and not mine.has(full):
				continue
			_catcher.take()
			var t: TestCase = script.new()
			if t == null:
				failed += 1
				print("  FAIL  %s: cannot instantiate" % full)
				continue
			var t0 := Time.get_ticks_msec()
			t.before_each()
			t.call(mname)
			t.after_each()
			for err in _catcher.take():
				t.failures.append("engine error: " + err)
			var dt := Time.get_ticks_msec() - t0
			if t.failures.is_empty():
				passed += 1
				print("  PASS  %s (%d ms)" % [full, dt])
			else:
				failed += 1
				print("  FAIL  %s (%d ms)" % [full, dt])
				for msg in t.failures:
					print("        - " + msg)
	print("")
	print("Tests: %d passed, %d failed, %.1f s" % [passed, failed, (Time.get_ticks_msec() - started) / 1000.0])
	return 1 if failed > 0 or passed == 0 else 0
