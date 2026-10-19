extends TestCase
## SC: scent clock pulls the pollution wave in; repelled waves put nests to sleep (audits still fire).


func _sim(seed_value: int, audit_days := 50.0) -> Simulation:
	var sim := Simulation.new(seed_value, make_bus(), null, {"audit_days": audit_days})
	sim.start_new_game()
	_sims.append(sim)
	return sim


func test_refines_pull_wave_in() -> void:
	var sim := _sim(4)
	sim.threats.awaken()
	sim.threats._k1_base_tick = sim.tick
	sim.run_ticks(31)
	var before: int = sim.threats.next_wave_tick - sim.threats._k1_base_tick
	for i in 10:
		sim.bus.batch_refined.emit(0, "refine")
	sim.run_ticks(31)
	var after: int = sim.threats.next_wave_tick - sim.threats._k1_base_tick
	assert_true(float(after) <= float(before) * 0.7, "wave pulled forward >= 30%% (%d -> %d)" % [before, after])


func test_dormancy_blocks_pollution_wave_not_audit() -> void:
	var sim := _sim(5, 2.0)
	sim.threats.awaken()
	sim.threats.wave_active = true
	sim.threats.end_wave()
	assert_gt(sim.threats.dormant_days_left(), 0.5, "nests sleep after repelled wave")
	assert_true(sim.threats.scent_ticker().begins_with("Nests dormant"))
	sim.threats.next_wave_tick = sim.tick + 1
	sim.run_ticks(60)
	assert_eq(sim.threats.wave_index, 0, "no pollution wave while dormant")
	sim.run_ticks(int(2.0 * sim.ticks_per_day))
	assert_gt(sim.threats.wave_index, 0, "audit patrol still fires inside dormancy")


func test_scent_decays() -> void:
	var sim := _sim(6)
	sim.bus.batch_refined.emit(0, "refine")
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_eq(sim.threats.scent_now(), 0.0)
