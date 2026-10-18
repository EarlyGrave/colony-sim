extends TestCase
## Research bench + job (R2c). Uses a stub research core until R2a is merged.


class StubResearch:
	extends RefCounted
	var progress := 0.0
	var goal := 600.0
	var is_active := true
	var done_tick := -1

	func active() -> String:
		return "stub_tech" if is_active and progress < goal else ""

	func add_progress(t: float) -> void:
		progress += t


func _setup(skill: int, benches := 1, with_stub := true) -> Array:
	var defs := peaceful_defs()
	defs.skills["xp_per_work_tick"] = 0.0  # keep the rate constant (no level-ups mid-run)
	var sim := make_sim(5, false, 24, 20, defs)
	var stub := StubResearch.new()
	if with_stub:
		sim.set_meta("research_stub", stub)
	var c := sim.colonists.spawn(Vector2i(3, 3))
	c.skills.levels["crafting"] = skill
	for i in benches:
		assert_true(sim.buildings.place("research_bench", Vector2i(8, 3 + i * 3), false) != null, "bench placed")
	return [sim, stub, c]


func _run(sim: Simulation, stub: StubResearch, ticks: int) -> int:
	for i in ticks:
		sim.step()
		if stub.progress >= stub.goal:
			return i + 1
	return -1


func test_speed_ratio_skill() -> void:
	var a := _setup(0)
	var b := _setup(10)
	var bench_a: Building = a[0].buildings.list[0]
	var bench_b: Building = b[0].buildings.list[0]
	var s0 := ResearchOperator.speed(a[0], bench_a, a[2])
	var s10 := ResearchOperator.speed(b[0], bench_b, b[2])
	assert_true(absf(s0 / s10 - 0.5 / 1.5) < 0.01, "ratio 0.5:1.5, got %f / %f" % [s0, s10])


func test_no_bench_no_progress() -> void:
	var sim := make_sim(5, false, 24, 20, peaceful_defs())
	var stub := StubResearch.new()
	sim.set_meta("research_stub", stub)
	sim.colonists.spawn(Vector2i(3, 3))
	sim.run_ticks(1000)
	assert_eq(stub.progress, 0.0)


func test_finishes_in_expected_time() -> void:
	var r := _setup(5)
	var rate := ResearchOperator.speed(r[0], r[0].buildings.list[0], r[2])
	var working := 0  # ticks that added progress (sleep breaks are not counted)
	for i in 3000:
		var before: float = r[1].progress
		r[0].step()
		if r[1].progress > before:
			working += 1
		if r[1].progress >= 600.0:
			break
	var want := int(ceil(600.0 / rate))
	assert_true(absi(working - want) <= 2, "working ticks %d vs ideal %d" % [working, want])


func test_two_benches_additive() -> void:
	var r := _setup(5, 2)
	var sim: Simulation = r[0]
	sim.colonists.spawn(Vector2i(4, 3)).skills.levels["crafting"] = 5
	var one := _setup(5, 1)
	var t1 := _run(one[0], one[1], 3000)
	var t2 := _run(sim, r[1], 3000)
	assert_true(t2 > 0 and t2 < t1 * 0.7, "two benches faster: %d vs %d" % [t2, t1])


func test_idle_without_active_tech() -> void:
	var r := _setup(5)
	r[1].is_active = false
	r[0].run_ticks(300)
	assert_eq(r[1].progress, 0.0)
	assert_true(r[2].job == null or r[2].job.type != "research")


func test_alarm_flees() -> void:
	var r := _setup(5)
	var sim: Simulation = r[0]
	sim.buildings.place("hq", Vector2i(16, 12), false)
	sim.run_ticks(80)
	assert_true(r[1].progress > 0.0, "researching")
	var before: float = r[1].progress
	sim.set_alarm(true)
	sim.run_ticks(5)
	assert_true(r[2].job != null and r[2].job.type == "flee", "flees on alarm")
	sim.run_ticks(300)
	assert_true(r[2].hidden, "hidden in shelter")
	var mid: float = r[1].progress
	sim.run_ticks(100)
	assert_eq(r[1].progress, mid, "no progress while hidden")
	assert_true(mid >= before)


func test_priority_off_disables() -> void:
	var r := _setup(5)
	r[0].set_work_priority(r[2].id, "researching", 0)
	r[0].run_ticks(300)
	assert_eq(r[1].progress, 0.0)
