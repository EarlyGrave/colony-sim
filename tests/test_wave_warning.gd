extends TestCase
## Wave direction warning: origin chosen in advance, signal fires once per wave.

var _incoming: Array = []


func _on_incoming(origin: Vector2i, ticks_left: int) -> void:
	_incoming.append([origin, ticks_left])


func _sim() -> Simulation:
	var sim := make_sim(7)
	_incoming.clear()
	sim.bus.wave_incoming.connect(_on_incoming)
	sim.threats.awaken()
	return sim


func test_origin_decided_before_wave() -> void:
	var sim := _sim()
	var o := sim.threats.next_spawn_origin
	assert_true(o.x >= 0, "origin chosen at awaken")
	sim.tick = sim.threats.next_wave_tick - 1
	assert_eq(sim.threats.next_spawn_origin, o)


func test_enemies_spawn_near_origin() -> void:
	var sim := _sim()
	var o := sim.threats.next_spawn_origin
	sim.threats.start_wave()
	assert_gt(sim.threats.enemies.size(), 0)
	var r := float(sim.threats.cfg["spawn_scatter"]) + 1.0
	for e: Enemy in sim.threats.enemies:
		assert_true(absf(e.cell.x - o.x) <= r and absf(e.cell.y - o.y) <= r, "enemy near origin")


func test_signal_fires_once_per_wave_before_start() -> void:
	var sim := _sim()
	var warn := int(sim.threats.cfg["warning_ticks"])
	var origin := sim.threats.next_spawn_origin
	var started := [false]
	sim.bus.wave_started.connect(func(_i: int, _s: float) -> void: started[0] = true)
	while not started[0] and sim.tick < 100000:
		sim.step()
	assert_eq(_incoming.size(), 1, "exactly one warning")
	assert_eq(_incoming[0][0], origin)
	assert_true(_incoming[0][1] <= warn)
	# Next wave gets its own warning and a fresh origin decision.
	sim.threats.end_wave()
	var n := _incoming.size()
	sim.tick = sim.threats.next_wave_tick - warn + 1
	sim.threats.tick()
	sim.threats.tick()
	assert_eq(_incoming.size(), n + 1)


func test_side_name() -> void:
	var sim := _sim()
	var c := sim.map_center()
	assert_eq(sim.threats.side_name(Vector2i(c.x, 0)), "севера")
	assert_eq(sim.threats.side_name(Vector2i(sim.map.width - 1, c.y)), "востока")
