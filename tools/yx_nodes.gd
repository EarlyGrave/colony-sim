extends SceneTree
## YX: node cells per resource on the home map for seeds 1..5 (static, no sim run).


func _init() -> void:
	var bus: Node = load("res://autoload/event_bus.gd").new()
	for s in range(1, 6):
		var sim := Simulation.new(s, bus, null, {"tutorial": true, "research_locked": true})
		sim.start_new_game()
		var cnt := {}
		for n in sim.map.node_cells():
			var r := sim.map.node_resource(n)
			cnt[r] = int(cnt.get(r, 0)) + 1
		print("seed ", s, " ", cnt)
		sim.dispose()
	quit()
