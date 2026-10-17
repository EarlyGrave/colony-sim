extends SceneTree
## Counts idle colonist-ticks in a 20-day standard_colony game.
## godot --headless --path . -s tools/idle_probe.gd
const Scenario := preload("res://tests/scenario.gd")


func _init() -> void:
	var bus: Node = load("res://autoload/event_bus.gd").new()
	for seed_value in [1, 2, 3]:
		var sim := Simulation.new(seed_value, bus)
		sim.start_new_game()
		Scenario.standard_colony(sim, 3)
		if "--dummy" in OS.get_cmdline_user_args():
			sim.buildings.place("training_dummy", Scenario.find_spot(sim, "training_dummy", sim.map_center() + Vector2i(0, -5), 0), false)
		var total := 0
		var idle := 0
		var why: Dictionary = {}
		var jobs: Dictionary = {}
		var days := 20
		for i in sim.ticks_per_day * days:
			sim.step()
			if sim.game_over_reason != "":
				break
			for c in sim.colonists.list:
				if not c.alive:
					continue
				total += 1
				if c.job == null:
					idle += 1
					var r := "none"
					if c.health != null and c.health.downed:
						r = "downed"
					elif c.is_sick(sim.tick):
						r = "sick"
					elif c.hidden:
						r = "hidden"
					elif c.carry_count > 0:
						r = "carrying"
					why[r] = int(why.get(r, 0)) + 1
					if r == "none" and sim.tick % 50 == 0 and OS.get_cmdline_user_args().has("--dbg"):
						print(sim.tick, " c", c.id, " prio ", c.skills.priorities, " idle_until ", c.idle_until, " alarm ", sim.alarm, " route ", sim.idle_work.route().size())
				else:
					jobs[c.job.type] = int(jobs.get(c.job.type, 0)) + 1
		print("seed %d idle %.1f%% (%d/%d) over=%s why=%s jobs=%s" % [seed_value, 100.0 * idle / maxi(total, 1), idle, total, sim.game_over_reason, str(why), str(jobs)])
		sim.dispose()
	bus.free()
	quit()
