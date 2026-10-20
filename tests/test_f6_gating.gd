extends TestCase
## F6 W1: beat gating ("wait" / "wait_max_days") in QuestLog.schedule and _on_tick.

const Q := "t_gate"


func _sim(wait: Variant, max_days := 3) -> Simulation:
	var sim := Simulation.new(5, make_bus(), peaceful_defs(), {})
	sim.start_new_game()
	_sims.append(sim)
	sim.run_ticks(1)
	var b: Dictionary = {"text": "gated beat", "wait": wait, "wait_max_days": max_days}
	sim.defs.quests[Q] = {"title": "t", "start": "a", "beats": {
		"a": {"text": "first", "then": "b", "delay_days": 1},
		"b": b}}
	return sim


func _beat_tick(sim: Simulation, beat: String) -> int:
	for e: Array in sim.quests.log:
		if e[1] == Q and e[2] == beat:
			return int(e[0])
	return -1


func test_waits_then_fires_when_cond_turns_true() -> void:
	var sim := _sim({"flag": "go"})
	sim.quests.start(Q)
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_eq(_beat_tick(sim, "b"), -1, "still waiting")
	sim.quests.set_flag("go")
	sim.run_ticks(sim.ticks_per_day * 2)
	var t := _beat_tick(sim, "b")
	assert_true(t >= 0, "fired after cond")
	assert_true(t <= sim.ticks_per_day * 4 + 5, "within a day of the flag")


func test_fires_at_max_wait_if_never_true() -> void:
	var sim := _sim({"flag": "never"}, 3)
	sim.quests.start(Q)
	var start := sim.tick
	sim.run_ticks(sim.ticks_per_day * 6)
	var t := _beat_tick(sim, "b")
	assert_true(t >= 0, "no stuck quest")
	assert_true(t >= start + sim.ticks_per_day * 4 - 2, "not before the limit")


func test_or_list() -> void:
	var sim := _sim([{"flag": "x"}, {"flag": "y"}])
	sim.quests.start(Q)
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_eq(_beat_tick(sim, "b"), -1)
	sim.quests.set_flag("y")
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_true(_beat_tick(sim, "b") >= 0)


func test_and_dict_needs_all() -> void:
	var sim := _sim({"flag": "x", "min_day": 1})
	sim.quests.start(Q)
	sim.quests.set_flag("x")
	sim.run_ticks(sim.ticks_per_day * 3)
	assert_true(_beat_tick(sim, "b") >= 0)


func test_limit_in_dump_only_with_wait() -> void:
	var sim := _sim({"flag": "never"})
	sim.quests.start(Q)
	sim.run_ticks(sim.ticks_per_day + 2)
	var sc: Array = sim.quests.state_parts()[4]
	assert_eq(sc.size(), 1)
	assert_eq((sc[0] as Array).size(), 4, "limit stored")
	var sim2 := _sim({"flag": "never"})
	sim2.defs.quests[Q]["beats"]["b"].erase("wait")
	sim2.quests.start(Q)
	sim2.run_ticks(1)
	assert_eq((sim2.quests.state_parts()[4][0] as Array).size(), 3, "no limit without wait")


func test_deterministic() -> void:
	var hs: Array[int] = []
	for _i in 2:
		var sim := _sim({"flag": "never"}, 2)
		sim.quests.start(Q)
		sim.run_ticks(sim.ticks_per_day * 2)
		sim.quests.set_flag("never")
		sim.run_ticks(sim.ticks_per_day * 2)
		hs.append(SaveGame.state_hash(sim))
	assert_eq(hs[0], hs[1])
