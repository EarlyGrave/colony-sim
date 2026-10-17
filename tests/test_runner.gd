extends Node
## Minimal headless test runner.
##
## Usage: godot --headless --path . res://tests/run_tests.tscn [-- --filter=substr]
## Finds res://tests/test_*.gd, runs every `test_*` method, exits with code 1
## on any failure.


func _ready() -> void:
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	var code := run_all(filter)
	get_tree().quit(code)


func run_all(filter: String) -> int:
	var files: Array[String] = []
	var dir := DirAccess.open("res://tests")
	for f in dir.get_files():
		var name := f.trim_suffix(".remap")
		if name.begins_with("test_") and name.ends_with(".gd") and name != "test_case.gd" and name != "test_runner.gd":
			files.append(name)
	files.sort()

	var passed := 0
	var failed := 0
	var started := Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		for m in script.get_script_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			var full := "%s::%s" % [f.get_basename(), mname]
			if filter != "" and not full.contains(filter):
				continue
			var t: TestCase = script.new()
			var t0 := Time.get_ticks_msec()
			t.before_each()
			t.call(mname)
			t.after_each()
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
