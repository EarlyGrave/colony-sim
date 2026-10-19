extends SceneTree
const Bot := preload("res://tests/qa_tutorial_bot.gd")
## PL: plate source/sink probe. godot --headless --path . -s tools/pl_diag.gd -- --seed=9 --days=60
func _init() -> void:
	var sd := 1
	var days := 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			sd = int(a.get_slice("=", 1))
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
	var bus = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(sd, bus, null, {"tutorial": true, "research_locked": true})
	sim.start_new_game()
	var bot = (load("res://tools/factory_bot.gd") as GDScript).new(sim)
	bot.cap_percent = 35
	bot.plate_target = 45
	var jobsum: Array = []
	var lim := days * sim.ticks_per_day
	while sim.tick < lim and sim.game_over_reason == "":
		bot.act()
		sim.run_ticks(Bot.STEP_TICKS)
		bot.after()
		if sim.tick % 300 < Bot.STEP_TICKS and sim.tick >= 12 * sim.ticks_per_day:
			var js := {}
			for c in sim.colonists.list:
				if c.alive:
					var k: String = c.job.get_script().resource_path.get_file().replace("_job.gd", "") if c.job != null else "idle"
					js[k] = int(js.get(k, 0)) + 1
			for b in sim.buildings.list:
				if b.def_id == "workbench":
					js["wb_prog%d" % b.id] = b.progress
					js["wb_in%d" % b.id] = int(b.input.get("essence_ore", 0))
			jobsum.append(js)
		if sim.tick % (sim.ticks_per_day * 3) < Bot.STEP_TICKS:
			var s := "res=%s amt=%s d%.0f plate=%d ore=%d ref=%d alive=%d pol=%.0f" % [str(sim.is_rule_on("ore_reserve")), str(sim.defs.rules["ore_reserve"]["amount"]), float(sim.tick) / sim.ticks_per_day, sim.items.count_stored("plate"), sim.items.count_stored("essence_ore"), sim.items.count_stored("refined_essence"), sim.colonists.alive_count(), sim.contamination.fraction() * 100.0]
			for b in sim.buildings.list:
				if b.def_id == "workbench":
					var bl := ""
					for bill: Bill in sim.crafting.bills_of(b):
						bl += "%s>%d%s " % [bill.recipe_id, bill.target, "P" if bill.paused else ""]
					s += " | wb@%s in=%s prog=%d brk=%s bills=%s" % [str(b.cell), str(b.input), b.progress, str(b.broken), bl]
			print(s)
	var tot := {}
	for js in jobsum:
		for k: String in js:
			if not k.begins_with("wb_"):
				tot[k] = int(tot.get(k, 0)) + int(js[k])
	print("JOBS ", tot, " samples=", jobsum.size())
	print("plate prod=", sim.ledger.produced.get("plate", 0), " cons=", sim.ledger.consumed.get("plate", 0))
	for k: String in sim.ledger.by_source:
		if "plate" in k:
			print(k, " ", sim.ledger.by_source[k])
	print(bot.log.slice(0, 60))
	quit()
