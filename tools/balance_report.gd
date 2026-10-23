extends SceneTree
## Prints wave outcomes for several seeds, with and without turrets.
## godot --headless --path . -s tools/balance_report.gd

const Scenario := preload("res://tests/scenario.gd")
const FactoryBot := preload("res://tools/factory_bot.gd")  # region F11W5


func _init() -> void:
	FactoryBot.f11_apply_env(Defs.get_default())  # region F11W5: TRAITS_V3=1 / PASSIVES_V2=1
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
			print("    objective_met=%d flee_deaths=%d hidden_starve=%d" % [sim.ledger.get_count("raid_objective_met"), sim.ledger.get_count("died:flee"), sim.ledger.get_count("starve:hidden")])  # region ST
			if sim.passives.enabled():  # region F11W5
				FactoryBot.f11_pick(sim)
				var f: Dictionary = FactoryBot.f11_stats(sim)
				print("    passives: marks earned=%d spent=%d keystones=%d rules=%s" % [f["earned"], f["spent"], f["keystones"], str(f["rules"])])
			for w in r["log"]:
				print("    ", w)
			sim.dispose()
			for c in bus.get_signal_list():
				for conn in bus.get_signal_connection_list(c["name"]):
					bus.disconnect(c["name"], conn["callable"])
	bus.free()
	quit()
