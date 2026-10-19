extends SceneTree
const Bot := preload("res://tests/qa_tutorial_bot.gd")
## FC: parts-stall probe. godot --headless --path . -s tools/fc_diag.gd -- --seed=4 --days=40
func _init() -> void:
	var sd := 4
	var days := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			sd = int(a.get_slice("=", 1))
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
	for a in OS.get_cmdline_user_args():
		if a == "--cu":
			Defs.get_default().balance["pg_bot"]["cu_first"] = 1
		if a == "--repfix":
			Defs.get_default().balance["repair_rock_fix"] = true
		if a == "--haulfix":
			Defs.get_default().balance["haul_blocked_fix"] = true
	var bus = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(sd, bus, null, {"tutorial": true, "research_locked": true})
	sim.start_new_game()
	var bot = (load("res://tools/factory_bot.gd") as GDScript).new(sim)
	bot.cap_percent = 35
	bot.plate_target = 45
	var lim := days * sim.ticks_per_day
	while sim.tick < lim and sim.game_over_reason == "":
		bot.act()
		sim.run_ticks(Bot.STEP_TICKS)
		bot.after()
		if sim.tick % (sim.ticks_per_day * 4) < Bot.STEP_TICKS:
			var s := "d%.0f plate=%d parts=%d cu=%d fe=%d" % [float(sim.tick) / sim.ticks_per_day, sim.items.count_stored("plate"), sim.items.count_stored("parts"), sim.items.count_stored("ingot_copper"), sim.items.count_stored("ingot_iron")]
			for b in sim.buildings.list:
				if b.def_id in ["assembler", "smelter", "miner"]:
					s += " | %s%s brk=%s in=%s out=%s pw=%.2f" % [b.def_id.substr(0, 3), str(b.cell), str(b.broken), str(b.input), str(b.output), sim.power.factor_for(b)]
			print(s)
	for bp in sim.buildings.blueprints:
		print("BP ", bp.def_id, bp.cell)
	for l in bot.log:
		print(l)
	quit()
