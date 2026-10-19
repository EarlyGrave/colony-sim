extends SceneTree
const Bot := preload("res://tests/qa_tutorial_bot.gd")
## OS: miner/smelter probe. godot --headless --path . -s tools/os_diag2.gd -- --seed=3 --days=40
func _init() -> void:
	var sd := 3
	var days := 40
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
	var lim := days * sim.ticks_per_day
	while sim.tick < lim and sim.game_over_reason == "":
		bot.act()
		sim.run_ticks(Bot.STEP_TICKS)
		bot.after()
	for b in sim.buildings.list:
		if b.def_id in ["miner", "smelter", "assembler", "gen", "storage_in"]:
			var extra := ""
			if b.def_id == "miner":
				extra = "res=%s " % sim.map.node_resource(b.node_cell)
			print("%s id=%d @%s brk=%s fac=%.2f out=%s in=%s prog=%d %s" % [b.def_id, b.id, str(b.cell), str(b.broken), sim.power.factor_for(b), str(b.output), str(b.input), b.progress, extra])
	print("ledger iron ", sim.ledger.produced.get("iron_ore", 0), " ingot ", sim.ledger.produced.get("ingot_iron", 0), " plate ", sim.ledger.produced.get("plate", 0))
	quit()
