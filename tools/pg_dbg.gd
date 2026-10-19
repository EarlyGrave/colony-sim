extends SceneTree
## PG scratch: dump map around a node after N days. -- --seed=4 --day=25 --x=50 --y=42
const FactoryBot := preload("res://tools/factory_bot.gd")
const Bot := preload("res://tests/qa_tutorial_bot.gd")


func _init() -> void:
	var seed_v := 4
	var day := 25
	var cx := 50
	var cy := 42
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_v = int(a.get_slice("=", 1))
		if a.begins_with("--day="):
			day = int(a.get_slice("=", 1))
		if a.begins_with("--x="):
			cx = int(a.get_slice("=", 1))
		if a.begins_with("--y="):
			cy = int(a.get_slice("=", 1))
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(seed_v, bus, null, {"tutorial": true, "research_locked": true})
	sim.start_new_game()
	var bot = FactoryBot.new(sim)
	while sim.tick < day * sim.ticks_per_day:
		bot.act()
		sim.run_ticks(Bot.STEP_TICKS)
		bot.after()
	for y in range(0, 64):
		var row := ""
		for x in range(0, 64):
			var c := Vector2i(x, y)
			var ch := "."
			if not sim.map.is_passable(c):
				ch = "#"
			if sim.map.is_node(c):
				ch = "N"
			if sim.map.is_mine_designated(c):
				ch = "m"
			if sim.buildings.occupied(c):
				ch = "B"
			elif ch == "." and not sim.pathfinder.reachable(sim.map_center(), c):
				ch = "?"
			row += ch
		print(y, " ", row)
	for b in sim.buildings.list:
		if b.def_id == "miner":
			var c0: Colonist = sim.colonists.list[0]
			print("ADJ ", sim.pathfinder.reachable(sim.map_center(), b.cell + Vector2i(-1, 0)), sim.pathfinder.reachable(sim.map_center(), b.cell + Vector2i(2, 0)), sim.pathfinder.best_adjacent(sim.map_center(), b.cell))
			print("REACH ", sim.pathfinder.reachable(sim.map_center(), b.cell), " c0 ", c0.cell, c0.alive, sim.map.is_passable(c0.cell), " dst ", sim.jobs._storage_for("coal", b.cell, c0, ""), " free ", sim.jobs._free(c0, "bout:%d" % b.id))
			print("MINER ", b.cell, " out=", b.output, " cond=", int(b.condition), " broken=", b.broken, " prog=", b.progress)
	print("coal stored ", sim.items.count_stored("coal"), " nitrogen ", sim.items.count_stored("nitrogen"), " ledger ", sim.ledger.produced.get("coal", 0), sim.ledger.produced.get("nitrogen", 0))
	print("step ", bot._step, " fails ", bot._step_fails)
	quit()
