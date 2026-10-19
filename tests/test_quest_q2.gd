extends TestCase
## Q2 Pilgrims of the Slag: trigger, three options, one-shot spawn override, determinism.


func _sim(seed_value := 5) -> Simulation:
	var sim := make_sim(seed_value, false, 30, 30, peaceful_defs())
	sim.colonists.spawn(Vector2i(4, 4))
	return sim


func test_disabled_is_inert() -> void:
	var sim := _sim()
	var q := Q2Pilgrims.new(sim)
	sim.contamination.level = 90.0
	q.poll()
	assert_eq(q.state, "idle")
	assert_eq(q.state_parts().size(), 0)


func test_trigger_at_40_percent_once() -> void:
	var sim := _sim()
	sim.defs.balance["q_enabled"] = true
	var q := Q2Pilgrims.new(sim)
	sim.contamination.level = 30.0
	q.poll()
	assert_eq(q.state, "idle")
	sim.contamination.level = 45.0
	q.poll()
	assert_eq(q.state, "offered")
	var n := sim.colonists.list.size()
	q.poll()
	assert_eq(sim.colonists.list.size(), n, "fires once")
	assert_eq(sim.colonists.get_by_id(q.oto_id).display_name, "Brother Oto")


func test_let_overrides_one_wave_only() -> void:
	var sim := _sim()
	var q := Q2Pilgrims.new(sim)
	q.begin()
	sim.threats.awaken()
	sim.threats.next_wave_tick = sim.tick + 100
	assert_true(q.resolve("let"))
	assert_eq(sim.threats.next_wave_tick, sim.tick + 100 + 300, "30 s late")
	assert_eq(sim.threats.q2.cell, q.dump_cell())
	assert_eq(sim.threats.next_spawn_origin, q.dump_cell())
	sim.threats.start_wave()
	assert_eq(sim.threats.q2.cell.x, -1, "cleared after the wave starts")
	sim.threats.end_wave()
	assert_eq(q.state, "done")


func test_silence_adds_mood_thought() -> void:
	var sim := _sim()
	var q := Q2Pilgrims.new(sim)
	q.begin()
	assert_true(q.resolve("silence"))
	for c in sim.colonists.list:
		assert_true(sim.mood.state_of(c).find("silenced_prayer") >= 0)
	assert_eq(sim.threats.q2.cell.x, -1)


func test_join_recruits_and_sets_mods() -> void:
	var sim := _sim()
	var q := Q2Pilgrims.new(sim)
	q.begin()
	var n := sim.colonists.list.size()
	assert_true(q.resolve("join"))
	assert_eq(sim.colonists.list.size(), n + 1)
	assert_eq(q.last_mods["refine_mult"], [0.85, 2.0])
	assert_eq(q.last_mods["wave_mult"], [0.8, 3.0])
	assert_false(q.resolve("join"), "answered once")


func test_determinism_of_oto_fate() -> void:
	var fates: Array = []
	for _r in 2:
		var sim := _sim(11)
		var q := Q2Pilgrims.new(sim)
		q.begin()
		q.resolve("let")
		fates.append(q.state_parts())
	assert_eq(fates[0], fates[1])


func test_oto_dies_on_roll() -> void:
	var sim := _sim()
	var q := Q2Pilgrims.new(sim)
	q.begin()
	q.resolve("let")
	q.oto_dies = true
	sim.threats.start_wave()
	sim.threats.end_wave()
	assert_false(sim.colonists.get_by_id(q.oto_id).alive)
