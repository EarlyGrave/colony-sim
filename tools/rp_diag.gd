extends SceneTree
const Bot := preload("res://tests/qa_tutorial_bot.gd")
## RP: miner repair probe + shuttle gap. godot --headless --path . -s tools/rp_diag.gd -- --seed=1 --days=60
func _init() -> void:
	var sd := 1
	var days := 60
	var fix := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			sd = int(a.get_slice("=", 1))
		if a.begins_with("--fix"):
			fix = true
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
	var bus = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(sd, bus, null, {"tutorial": true, "research_locked": true})
	sim.defs.balance["repair_rock_fix"] = fix
	sim.start_new_game()
	var bot = (load("res://tools/factory_bot.gd") as GDScript).new(sim)
	bot.cap_percent = 35
	bot.plate_target = 45
	var lim := days * sim.ticks_per_day
	while sim.tick < lim and sim.game_over_reason == "":
		bot.act()
		sim.run_ticks(Bot.STEP_TICKS)
		bot.after()
		if sim.tick % (sim.ticks_per_day * 2) < Bot.STEP_TICKS:
			var s := "d%.0f plate=%d alive=%d" % [float(sim.tick) / sim.ticks_per_day, sim.items.count_stored("plate"), sim.colonists.alive_count()]
			for b in sim.buildings.list:
				if b.def_id == "miner" and sim.map.node_resource(b.node_cell) == "iron_ore":
					var w := 0
					for c in sim.colonists.list:
						if c.alive and c.job is RepairJob:
							w += 1
					s += " | iron_miner@%s brk=%s cond=%.0f hp=%d out=%s repairers=%d" % [str(b.cell), str(b.broken), b.condition, b.hp, str(b.output), w]
			print(s)
	for b in sim.buildings.list:
		if b.def_id == "miner":
			var ns := ""
			for dy in range(-1, 3):
				for dx in range(-1, 3):
					var q: Vector2i = b.cell + Vector2i(dx, dy)
					ns += ("." if sim.pathfinder.is_walkable(q) else ("#" if not sim.map.is_passable(q) else "B"))
				ns += "/"
			print("MINER ", b.cell, " ", ns, " walk=", sim.pathfinder.is_walkable(b.cell), " broken=", b.broken)
	for b in sim.buildings.list:
		if b.broken:
			for c in sim.colonists.list:
				if c.alive:
					print("BRK ", b.def_id, b.cell, " col ", c.id, c.cell, " reach=", sim.pathfinder.reachable(c.cell, b.cell), " free=", sim.jobs._free(c, "rep:%d" % b.id), " needs=", b.needs_repair(sim), " pri=", sim.get_work_priority(c.id, "repair") if sim.has_method("get_work_priority") else "?", " job=", c.job.type if c.job != null else "idle")
	print("RESULT ", sim.game_over_reason, " iron_prod=", sim.ledger.produced.get("iron_ore", 0))
	print("GAP refined=", sim.items.count_stored("refined_essence"), " plate=", sim.items.count_stored("plate"), " parts=", sim.items.count_stored("parts"), " nitrogen=", sim.items.count_stored("nitrogen"), " fuel=", sim.items.count_stored("fuel_cell"), " iron_ore_prod=", sim.ledger.produced.get("iron_ore", 0), " tier_done=", str(sim.milestones.is_tier_done(2)))
	quit()
