extends SceneTree
## Prints wave outcomes for several seeds, with and without turrets.
## godot --headless --path . -s tools/balance_report.gd

const Scenario := preload("res://tests/scenario.gd")


func _init() -> void:
	var bus: Node = load("res://autoload/event_bus.gd").new()
	for mode in [[0, false], [3, false], [3, true]]:
		var turrets: int = mode[0]
		print("=== turrets: %d, intervene: %s" % [turrets, mode[1]])
		for seed_value in [1, 2, 3, 4, 5]:
			var sim := Simulation.new(seed_value, bus)
			sim.start_new_game()
			Scenario.standard_colony(sim, turrets)
			var r := Scenario.run_waves(sim, 8, mode[1])
			print("seed %d: over=%s died_on_wave=%d waves=%d day=%d batches=%d cont=%.1f breakdowns=%d built=%d" % [
				seed_value, r["game_over"], r["died_on_wave"], r["waves"], sim.day(), r["batches"], r["contamination"], r["breakdowns"], r["turrets_built"]])
			for w in r["log"]:
				print("    ", w)
			sim.dispose()
			for c in bus.get_signal_list():
				for conn in bus.get_signal_connection_list(c["name"]):
					bus.disconnect(c["name"], conn["callable"])
	bus.free()
	quit()
