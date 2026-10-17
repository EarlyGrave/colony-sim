extends SceneTree
## Prints perk points earned per colonist over 20 days (standard colony, 3 turrets).
## godot --headless --path . -s tools/progression_report.gd

const Scenario := preload("res://tests/scenario.gd")


func _init() -> void:
	var bus: Node = load("res://autoload/event_bus.gd").new()
	for seed_value in [1, 2, 3, 4, 5]:
		var sim := Simulation.new(seed_value, bus)
		sim.start_new_game()
		Scenario.standard_colony(sim, 3)
		var by_reason := {}
		sim.bus.xp_awarded.connect(func(_id: int, _s: String, a: float, r: String) -> void:
			by_reason[r] = float(by_reason.get(r, 0.0)) + a)
		sim.run_ticks(sim.ticks_per_day * 20)
		var pts: Array = []
		for c in sim.colonists.list:
			var n := 0
			for s: String in c.skills.levels:
				n += sim.perks.points_available(c, s) + sim.perks.spent(c, s)
			pts.append(n if c.alive else -n)
		print("seed %d day=%d waves=%d points=%s event_xp=%s" % [seed_value, sim.day(), sim.threats.wave_index, str(pts), str(by_reason)])
		sim.dispose()
		for c in bus.get_signal_list():
			for conn in bus.get_signal_connection_list(c["name"]):
				bus.disconnect(c["name"], conn["callable"])
	bus.free()
	quit()
