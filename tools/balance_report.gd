extends SceneTree
## Prints wave outcomes for several seeds, with and without turrets.
## godot --headless --path . -s tools/balance_report.gd

const Scenario := preload("res://tests/scenario.gd")


func _init() -> void:
	var bus: Node = load("res://autoload/event_bus.gd").new()
	for mode in [[0, false, false], [3, false, false], [3, true, false], [3, true, true]]:
		var turrets: int = mode[0]
		print("=== turrets: %d, intervene: %s, engineer rule: %s" % [turrets, mode[1], mode[2]])
		for seed_value in [1, 2, 3, 4, 5]:
			var sim := Simulation.new(seed_value, bus)
			sim.start_new_game()
			Scenario.standard_colony(sim, turrets)
			sim.set_rule("raid_engineer", mode[2])
			var r := Scenario.run_waves(sim, 8, mode[1])
			print("seed %d: over=%s died_on_wave=%d waves=%d day=%d batches=%d cont=%.1f breakdowns=%d built=%d events=%s" % [
				seed_value, r["game_over"], r["died_on_wave"], r["waves"], sim.day(), r["batches"], r["contamination"], r["breakdowns"], r["turrets_built"], str(sim.storyteller.fired)])
			for w in r["log"]:
				print("    ", w)
			sim.dispose()
			for c in bus.get_signal_list():
				for conn in bus.get_signal_connection_list(c["name"]):
					bus.disconnect(c["name"], conn["callable"])
	bus.free()
	quit()
