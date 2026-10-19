extends SceneTree
## Quest probe: runs plain sims with q_enabled and auto-answers choices (first enabled option, or --pick=<option>).
## godot --headless --path . -s tools/quest_probe.gd -- --seeds=1-10 --days=60 [--quest=<id>] [--pick=<option>]
## Prints per-seed fired quests/beats and a fired-count summary. Bot-driven triggers (audits, debt) need factory_eval.sh --ov='{"q_enabled":true}'.


func _init() -> void:
	var seeds := "1-10"
	var days := 60
	var only := ""
	var pick := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = a.substr(8)
		elif a.begins_with("--days="):
			days = int(a.substr(7))
		elif a.begins_with("--quest="):
			only = a.substr(8)
		elif a.begins_with("--pick="):
			pick = a.substr(7)
	var lo := int(seeds.get_slice("-", 0))
	var hi := int(seeds.get_slice("-", 1)) if "-" in seeds else lo
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var fired: Dictionary = {}
	for seed_value in range(lo, hi + 1):
		var defs := Defs.get_default().duplicate_defs()
		defs.balance["q_enabled"] = true
		var sim := Simulation.new(seed_value, bus, defs)
		sim.start_new_game()
		var total := days * sim.ticks_per_day
		for i in total:
			sim.step()
			if sim.game_over_reason != "":
				break
			for p in sim.quests.pending.duplicate():
				if only != "" and p["quest"] != only:
					continue
				var oid := ""
				for o: Dictionary in p["options"]:
					if bool(o["enabled"]) and (pick == "" or o["id"] == pick):
						oid = o["id"]
						break
				if oid != "":
					sim.answer_quest(int(p["uid"]), oid)
		var names: Array = []
		for id: String in sim.quests.quests:
			if only == "" or id == only:
				names.append("%s:%s@%s" % [id, sim.quests.state(id), sim.quests.quests[id]["beat"]])
				fired[id] = int(fired.get(id, 0)) + 1
		print("seed %d day %d over=%s quests=%s flags=%s" % [seed_value, sim.day(), sim.game_over_reason, str(names), str(sim.quests.flags.keys())])
		sim.dispose()
		for c in bus.get_signal_list():
			for conn in bus.get_signal_connection_list(c["name"]):
				bus.disconnect(c["name"], conn["callable"])
	print("FIRED SUMMARY (of %d seeds): %s" % [hi - lo + 1, str(fired)])
	bus.free()
	quit()
