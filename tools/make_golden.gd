extends SceneTree
## Regenerates tests/golden/*.json (intentional baseline change only).
## godot --headless --path . -s tools/make_golden.gd -- --regen [--only=name]

const Golden := preload("res://tests/golden.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--regen"):
		print("Refusing to overwrite goldens without --regen.")
		quit(1)
		return
	var only := ""
	for a in args:
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	var failed := false
	for name in Golden.NAMES:
		if only != "" and only != name:
			continue
		var spec: Dictionary = Golden.SPECS[name]
		var old := Golden.load_golden(name)
		var res := Golden.run(spec, [], Golden.script_for(name))
		if res["game_over"] != "" or res["hashes"].size() != Golden.TOTAL / Golden.STEP:
			print("%s: BAD scenario (game_over=%s, %d hashes)" % [name, res["game_over"], res["hashes"].size()])
			failed = true
			continue
		var changed: Array[String] = []
		for k: String in res["hashes"]:
			if old.is_empty() or int(old["hashes"].get(k, -1)) != int(res["hashes"][k]):
				changed.append(k)
		Golden.write_golden(name, spec, res)
		print("%s: %d commands, %d/%d hashes changed%s" % [name, res["commands"].size(), changed.size(), res["hashes"].size(),
			(" (first at tick " + changed[0] + ")") if not changed.is_empty() else ""])
	quit(1 if failed else 0)
