extends TestCase
## EN2: Submit ending: manifest seats, siege scaling, New Names hook. No path = old shuttle.


func _sim(path: String) -> Simulation:
	var d := peaceful_defs()
	d.balance["s1_enabled"] = true
	d.balance["e1_enabled"] = true
	var sim := make_sim(5, false, 30, 30, d)
	for i in 3:
		sim.colonists.spawn(Vector2i(4 + i, 4))
	sim.petition.done_phases = [1, 2, 3, 4]
	if path != "":
		sim.set_path(path)
	sim.run_ticks(1)
	return sim


func test_seats_default_and_manifest() -> void:
	var sim := _sim("submit")
	assert_eq(sim.shuttle.parts_need(), 3, "one part per colonist")
	assert_true(sim.set_manifest(2))
	assert_eq(sim.shuttle.parts_need(), 2)
	assert_false(sim.set_manifest(0))
	sim.set_manifest(99)
	assert_eq(sim.shuttle.seats(), 3, "clamped to the living")


func test_no_path_keeps_parts_list() -> void:
	var sim := _sim("")
	assert_eq(sim.shuttle.parts_need(), 24)
	assert_eq(sim.shuttle.siege_mult(), 1.0)


func test_siege_mult_scales_with_pollution() -> void:
	var sim := _sim("submit")
	var cap := float(sim.defs.balance["contamination"]["max"])
	for f: float in [0.0, 0.5, 1.0]:
		sim.contamination.level = cap * f
		assert_true(absf(sim.shuttle.siege_mult() - (1.0 + f)) < 0.001, "x(1+%s)" % f)


func test_win_submit_sets_ending_and_hook() -> void:
	var sim := _sim("submit")
	sim.set_manifest(2)
	sim.shuttle.parts = 2
	sim.buildings.place("release_gantry", Vector2i(10, 6), false)
	sim.shuttle.counting = true
	sim.shuttle.t_left = 1
	var won: Array = []
	sim.bus.ending_won.connect(func(id: String) -> void: won.append(id))
	sim.run_ticks(3)
	assert_eq(won, ["submit"])
	assert_true(sim.quests.flag("ng_new_names"))
	assert_eq(sim.shuttle.freed, 2)
	assert_eq(sim.shuttle.stayed, 1)


func test_no_path_win_has_no_ending() -> void:
	var sim := _sim("")
	sim.buildings.place("release_gantry", Vector2i(10, 6), false)
	sim.shuttle.counting = true
	sim.shuttle.t_left = 1
	sim.run_ticks(3)
	assert_true(sim.shuttle.won)
	assert_false(sim.endings.won("submit"))


func test_notices_stepwise_and_stop_at_launch() -> void:
	var sim := _sim("submit")
	sim.quests.set_flag("ponr_x")
	sim.petition.done_phases = [1, 2, 3, 4]
	sim.defs.shuttle["notice_days"] = 0.5
	var every := sim.ticks_per_day / 2
	sim.run_ticks(every * 2 - sim.tick + 1)
	assert_true(sim.shuttle.notices >= 2)
	var n: int = sim.shuttle.notices
	sim.buildings.place("release_gantry", Vector2i(10, 6), false)
	sim.shuttle.counting = true
	sim.shuttle.t_left = every * 3
	sim.run_ticks(every)
	assert_eq(sim.shuttle.notices, n, "stops once counting")
