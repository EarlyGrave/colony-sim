extends SceneTree
const Bot := preload("res://tests/qa_tutorial_bot.gd")
## RF: refinery duty-cycle probe. godot --headless --path . -s tools/rf_diag.gd -- --seed=1 --days=40
func _init() -> void:
	var sd := 1
	var days := 40
	var capv := 35
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			sd = int(a.get_slice("=", 1))
		if a.begins_with("--margin="):
			for r in ["smelt_iron", "smelt_copper"]:
				Defs.get_default().recipes[r]["cap_margin"] = int(a.get_slice("=", 1))
		if a.begins_with("--cap="):
			capv = int(a.get_slice("=", 1))
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
	var bus = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(sd, bus, null, {"tutorial": true, "research_locked": true})
	sim.start_new_game()
	var bot = (load("res://tools/factory_bot.gd") as GDScript).new(sim)
	bot.cap_percent = capv
	bot.plate_target = 45
	var lim := days * sim.ticks_per_day
	var busy := 0
	var samples := 0
	var capped := 0
	var brk := 0
	var empty_in := 0
	while sim.tick < lim and sim.game_over_reason == "":
		bot.act()
		sim.run_ticks(Bot.STEP_TICKS)
		bot.after()
		for b in sim.buildings.list:
			if b.def_id == "refinery":
				samples += 1
				if b.progress > 0:
					busy += 1
				if b.broken:
					brk += 1
				if sim.buildings.refining_capped():
					capped += 1
				if int(b.input.get("essence_ore", 0)) < 10:
					empty_in += 1
		if sim.tick % 150 == 0 and sim.tick > 34 * sim.ticks_per_day and sim.tick < 41 * sim.ticks_per_day:
			var m := ""
			for b in sim.buildings.list:
				if b.progress > 0:
					m += " %s:%s" % [b.def_id, b.recipe_id]
			print("T d%.2f pol=%.1f wu=%.0f%s" % [float(sim.tick) / sim.ticks_per_day, sim.contamination.level, sim.contamination.waste_units(), m])
		if sim.tick % 1200 == 0:
			var s := "wu=%.1f mr=%.2f cap=%s d%.1f ore=%d ref=%d pol=%.0f" % [sim.contamination.waste_units(), sim.contamination.machine_rate_per_day(), str(sim.is_rule_on("refine_cap")), float(sim.tick) / sim.ticks_per_day, sim.items.count_stored("essence_ore"), sim.items.count_stored("refined_essence"), sim.contamination.fraction() * 100.0]
			for b in sim.buildings.list:
				if b.def_id == "refinery" or b.def_id == "workbench":
					s += " | %s in=%s prog=%d brk=%s hp=%d" % [b.def_id, str(b.input), b.progress, str(b.broken), int(b.hp)]
			print(s)
	for it in ["ingot_iron","ingot_copper","plate","parts","iron_ore","copper_ore","waste"]:
		print(it, " stock=", sim.items.count_stored(it), " prod=", sim.ledger.produced.get(it, 0), " cons=", sim.ledger.consumed.get(it, 0))
	var bc := {}
	for b in sim.buildings.list:
		bc[b.def_id] = int(bc.get(b.def_id, 0)) + 1
	print(bc)
	for b in sim.buildings.list:
		if b.def_id == "smelter":
			print("smelter ", b.recipe_id, " ", b.cell, " ", bot._smelt_res.get(b.cell, "?"))
	print(bot.log.filter(func(l): return "dismantle" in l or "rebuild" in l))
	print("samples=%d busy=%d capped=%d broken=%d input<10=%d" % [samples, busy, capped, brk, empty_in])
	var jobs := {}
	for c in sim.colonists.list:
		var k := "none"
		if c.job != null:
			k = c.job.get_script().resource_path.get_file()
		jobs[k] = int(jobs.get(k, 0)) + 1
	print(jobs)
	quit()
