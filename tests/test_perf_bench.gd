extends TestCase


func test_map_size_option() -> void:
	var sim := Simulation.new(3, make_bus(), peaceful_defs(), {"map_w": 96, "map_h": 80})
	sim.start_new_game()
	_sims.append(sim)
	assert_eq(sim.map.width, 96)
	assert_eq(sim.map.height, 80)
	assert_eq(sim.map_center(), Vector2i(48, 40))
	# Colony area is connected: every colonist can reach the HQ surroundings.
	var center := sim.map_center()
	for c in sim.colonists.list:
		assert_true(sim.pathfinder.reachable_terrain(c.cell, center + Vector2i(3, -1)), "colonist cut off")


func test_default_size_unchanged() -> void:
	var sim := make_sim(1)
	assert_eq(sim.map.width, int(sim.defs.balance["map"]["width"]))


func test_bench_runs() -> void:
	var out: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"res://tools/perf_bench.tscn", "--", "--ticks=20", "--size=96", "--enemies=20"], out, true)
	assert_eq(code, 0, "bench exit code")
	var text := "\n".join(PackedStringArray(out))
	for k in ["buildings", "colonists", "threats", "contamination", "mutation", "storyteller", "jobs", "combat"]:
		assert_true(text.contains(k), "missing line " + k)
