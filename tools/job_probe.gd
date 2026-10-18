extends SceneTree
## Times JobSystem.assign() for idle colonists during a standard_colony game (tool code, not sim).
## godot --headless --path . -s tools/job_probe.gd
const Scenario := preload("res://tests/scenario.gd")


func _init() -> void:
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(1, bus)
	sim.start_new_game()
	Scenario.standard_colony(sim, 8)
	var t_all := 0
	var t_step := 0
	var n := 0
	var ticks := 3000
	for i in ticks:
		var a := Time.get_ticks_usec()
		sim.step()
		t_step += Time.get_ticks_usec() - a
		if i % 5 == 0:
			for c in sim.colonists.list:
				if c.alive and c.job == null and c.carry_count == 0:
					var b := Time.get_ticks_usec()
					sim.jobs.assign(c)
					t_all += Time.get_ticks_usec() - b
					n += 1
	print("step avg %.3f ms/tick; assign avg %.3f ms over %d calls (~%.4f ms/tick upper bound)" % [t_step / 1000.0 / ticks, t_all / 1000.0 / maxi(n, 1), n, t_all / 1000.0 / ticks * 5.0])
	sim.dispose()
	bus.free()
	quit()
