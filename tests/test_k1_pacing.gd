extends TestCase
## K1: preset pacing (calm after a hit, sentence-audit floor clock).


func _sim(seed_value: int, audit_days: float, calm_mult := 1.0) -> Simulation:
	var sim := Simulation.new(seed_value, make_bus(), null, {"audit_days": audit_days, "calm_mult": calm_mult})
	sim.start_new_game()
	_sims.append(sim)
	return sim


func test_audit_fires_on_schedule_without_pollution() -> void:
	var sim := _sim(3, 3.0)
	var at: int = sim.threats.next_audit_tick()
	assert_eq(at, int(3.0 * sim.ticks_per_day))
	assert_true(not sim.threats.awakened, "clean colony is not awakened")
	sim.run_ticks(at - 1)
	assert_eq(sim.threats.wave_index, 0)
	sim.run_ticks(2)
	assert_eq(sim.threats.wave_index, 1, "audit patrol spawned")
	assert_gt(sim.threats.next_audit_tick(), at, "next audit re-armed")
	assert_gt(sim.threats.days_to_audit(), 2.0)


func test_no_pacing_without_opts() -> void:
	var sim := make_sim(3)
	assert_eq(sim.threats.next_audit_tick(), -1)
	assert_eq(sim.threats.days_to_audit(), -1.0)


func test_calm_suppresses_regular_wave() -> void:
	var sim := _sim(4, 50.0)
	sim.threats.awaken()
	sim.threats.next_wave_tick = sim.tick + 5
	sim.threats._k1_calm_until = sim.tick + 400
	sim.run_ticks(300)
	assert_eq(sim.threats.wave_index, 0, "calm holds the wave")
	sim.run_ticks(200)
	assert_eq(sim.threats.wave_index, 1, "wave comes after the calm")


func test_hit_starts_calm() -> void:
	var sim := _sim(4, 50.0, 2.0)
	sim.threats.wave_active = true
	sim.threats._k1_hit = true
	sim.threats.end_wave()
	var days := float(sim.threats._k1_calm_until - sim.tick) / float(sim.ticks_per_day)
	assert_near(days, 4.0, 0.01, "short preset calm = 2 days x 2")


func test_deterministic() -> void:
	var a := _sim(7, 3.0)
	var b := _sim(7, 3.0)
	a.run_ticks(5 * a.ticks_per_day)
	b.run_ticks(5 * b.ticks_per_day)
	assert_eq(a.threats.wave_index, b.threats.wave_index)
	assert_eq(a.threats.enemies.size(), b.threats.enemies.size())
	assert_eq(a.threats.next_audit_tick(), b.threats.next_audit_tick())
