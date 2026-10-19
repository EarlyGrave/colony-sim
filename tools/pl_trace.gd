extends SceneTree
## PL: per-day trace of the real factory bot. -- --seed=1 --days=60
const FactoryBot := preload("res://tools/factory_bot.gd")
const Bot := preload("res://tests/qa_tutorial_bot.gd")


func _init() -> void:
	var seed_v := 1
	var days := 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_v = int(a.get_slice("=", 1))
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
	var cap := 50
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cap="):
			cap = int(a.get_slice("=", 1))
		if a.begins_with("--ov="):
			load("res://tools/factory_bot_report.gd").apply_overrides(Defs.get_default(), JSON.parse_string(a.substr(5)))
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(seed_v, bus, null, {"tutorial": true, "research_locked": true})
	sim.start_new_game()
	var bot = FactoryBot.new(sim)
	bot.cap_percent = cap
	var lastd := -1
	var seen := {}
	while sim.tick < days * sim.ticks_per_day and sim.game_over_reason == "":
		bot.act()
		sim.run_ticks(Bot.STEP_TICKS)
		bot.after()
		if sim.day() >= 38 and sim.day() < 40 and sim.tick % 120 == 0:
			print("STEP t=%d lvl=%.3f mr=%.2f cap=%s wu=%.1f" % [sim.tick, sim.contamination.level, sim.contamination.machine_rate_per_day(), str(sim.buildings.refining_capped()), sim.contamination.waste_units()])
		if sim.day() != lastd:
			lastd = sim.day()
			var rd := ""
			for t in ["conveyance", "crude_refining", "drilling", "smelting", "storage_ports", "assembly", "filters", "electrification"]:
				if sim.research.is_done(t) and not seen.has(t):
					seen[t] = true
					print("RESEARCH ", t, " done d", lastd)
			if lastd % 2 == 0 and lastd < 34:
				print("RQ d%d queue=%s active=%s prog=%s refined=%d" % [lastd, str(sim.research.queue), sim.research.active(), str(sim.research.progress), sim.items.count_stored("refined_essence")])
			print("BOT d%d pending=%s mine=%s routes=%d bps=%s" % [lastd, str(bot._pending()), str(bot._mine), bot._routes.size(), str(sim.buildings.blueprints.map(func(b): return b.def_id + '@' + str(b.cell) + ' del=' + str(b.delivered_total())))])
			var brk := 0
			var names := {}
			for b in sim.buildings.list:
				if b.broken:
					brk += 1
					names[b.def_id] = int(names.get(b.def_id, 0)) + 1
			print("waste=%d cmp=%d refP=%d " % [sim.items.count_stored("waste"), sim.buildings.count_of("waste_compactor"), int(sim.ledger.produced.get("refined_essence",0))], "pol=%d%% ingP=%d/%d cap=%s " % [sim.contamination.fraction()*100, int(sim.ledger.produced.get("ingot_iron",0)), int(sim.ledger.produced.get("ingot_copper",0)), str(sim.is_rule_on("refine_cap"))], "d%d step=%d plate=%d(p%d/c%d) ingFe=%d ingCu=%d parts=%d asm=%d done[asm=%s] broken=%d %s" % [lastd, bot._step, sim.items.count_stored("plate"),
				int(sim.ledger.produced.get("plate", 0)), int(sim.ledger.consumed.get("plate", 0)), sim.items.count_stored("ingot_iron"), sim.items.count_stored("ingot_copper"),
				sim.items.count_stored("parts"), sim.buildings.count_of("assembler"), sim.research.is_done("assembly"), brk, str(names)])
			if lastd % 5 == 0:
				var parts: Array[String] = []
				for b in sim.buildings.list:
					if b.def_id in ["smelter", "miner", "assembler", "workbench", "refinery"]:
						parts.append("%s@%d,%d[%s p%d in=%s out=%s cond=%d]" % [b.def_id, b.cell.x, b.cell.y, b.recipe_id, b.progress, str(b.input), str(b.output), int(b.condition)])
				print("   ", " ".join(parts), " rate=", sim.contamination.rate_per_day, " mrate=", sim.contamination.machine_rate_per_day(), " lvl=", sim.contamination.level, " wu=", sim.contamination.waste_units())
	sim.dispose()
	quit()
