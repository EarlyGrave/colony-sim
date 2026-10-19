extends SceneTree
## PG: prints the bot build log + node distances for one seed. -- --seed=4 --days=60
const FactoryBot := preload("res://tools/factory_bot.gd")


func _init() -> void:
	var s := 1
	var days := 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			s = int(a.get_slice("=", 1))
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
	var r: Dictionary = FactoryBot.play(s, days, {})
	print("\n".join(r["log"]))
	print(r["built"])
	print(r["ledger"])
	print("pf ", r["power_factor"], " phase ", r["phase_day"], " audit ", r["audit_day"])
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(s, bus, null, {"tutorial": true, "research_locked": true})
	sim.start_new_game()
	var hub := sim.map_center() + Vector2i(-2, 9)
	for res in ["iron_ore", "copper_ore", "coal", "nitrogen"]:
		var ds := []
		for n in sim.map.node_cells():
			if sim.map.node_resource(n) == res:
				ds.append(int(Vector2(n - hub).length()))
		ds.sort()
		print(res, " dists ", ds)
	for res in ["copper_ore", "iron_ore"]:
		for n in sim.map.node_cells():
			if sim.map.node_resource(n) == res and Vector2(n - hub).length() > 15:
				var row := ""
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var p: Vector2i = n + Vector2i(dx, dy)
						row += "%s/%s " % [str(sim.map.tile_at(p)) if sim.map.has_method("tile_at") else "?", sim.map.node_resource(p) if sim.map.is_node(p) else "-"]
				print(res, n, " ", row, " err ", sim.buildings.placement_error("miner", n, false))
	quit()
