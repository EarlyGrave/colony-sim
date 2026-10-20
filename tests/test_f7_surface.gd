extends TestCase
## F7W3: dedicated regulation / fixation signals (inert while flags OFF) + PA lines for regulations.

var _log: Array = []


func _watch(sim: Simulation) -> void:
	_log.clear()
	var b: Node = sim.bus
	b.regulation_offered.connect(func(s: int) -> void: _log.append(["ro", s]))
	b.regulation_chosen.connect(func(s: int, id: String, t: bool) -> void: _log.append(["rc", s, id, t]))
	b.fixation_offered.connect(func(c: int, i: String) -> void: _log.append(["fo", c, i]))
	b.fixation_done.connect(func(c: int, i: String) -> void: _log.append(["fd", c, i]))
	b.fixation_failed.connect(func(c: int) -> void: _log.append(["ff", c]))


func _count(kind: String) -> int:
	var n := 0
	for e in _log:
		if e[0] == kind:
			n += 1
	return n


func _defs(on: bool) -> Defs:
	var d := peaceful_defs()
	d.balance["reg_enabled"] = on
	d.balance["fixation_enabled"] = on
	for i in 3:
		d.regulations["slots"][i]["day"] = i + 1
	return d


func test_flags_off_emit_nothing() -> void:
	var sim := make_sim(3, true, 24, 24, _defs(false))
	_watch(sim)
	sim.run_ticks(30 * sim.ticks_per_day)
	assert_eq(_log.size(), 0, "no F7W3 signal while flags OFF")


func test_regulation_offer_choose_and_timeout() -> void:
	var sim := make_sim(3, true, 24, 24, _defs(true))
	_watch(sim)
	sim.run_ticks(sim.ticks_per_day + 5)
	assert_eq(_count("ro"), 1)
	assert_eq(_log[0][1], 0)
	assert_true(sim.choose_regulation(0, "overtime"))
	assert_eq(_count("rc"), 1)
	assert_eq(_log[_log.size() - 1], ["rc", 0, "overtime", false])
	sim.run_ticks(sim.ticks_per_day)
	assert_eq(_count("ro"), 2, "slot 1 offered")
	sim.run_ticks(int(sim.regulations.timeout_ticks) + 5)
	assert_eq(_count("rc"), 2, "timeout answered once")
	var last: Array = []
	for e in _log:
		if e[0] == "rc":
			last = e
	assert_eq(last, ["rc", 1, "comply", true])


func test_fixation_signals() -> void:
	var sim := Simulation.new(3, make_bus(), _defs(true), {})
	sim.start_new_game()
	_sims.append(sim)
	sim.run_ticks(1)
	_watch(sim)
	for c in sim.colonists.list:
		c.skills.levels["crafting"] = 4
	sim.tick = 24 * sim.ticks_per_day
	sim.ledger.record_produced("plate", 8, "test")
	sim.items.drop(Vector2i(8, 6), "plate", 8)
	sim.ledger.record_produced("refined_essence", 3, "test")
	sim.items.drop(Vector2i(9, 7), "refined_essence", 3)
	var p: Dictionary = {}
	for _i in 2 * sim.ticks_per_day:
		sim.run_ticks(1)
		for q in sim.storyteller.pending:
			if q["kind"] == "fixation":
				p = q
		if not p.is_empty():
			break
	assert_false(p.is_empty(), "offered")
	assert_eq(_count("fo"), 1)
	assert_eq(_log[_log.size() - 1][1], int(p["cid"]))
	for b in sim.buildings.list.duplicate():
		if b.def_id == str(sim.defs.fixation["bench"]):
			b.destroyed = true
	sim.answer_event(int(p["uid"]), true)  # no bench: fails at the deadline
	sim.run_ticks(4 * sim.ticks_per_day)
	assert_eq(_count("ff"), 1, "failed once")
	assert_eq(_count("fd"), 0)


func test_fixation_done_signal() -> void:
	var Scen := load("res://tests/scenario.gd")
	var sim := Simulation.new(3, make_bus(), _defs(true), {})
	sim.start_new_game()
	_sims.append(sim)
	sim.run_ticks(1)
	_watch(sim)
	for c in sim.colonists.list:
		c.skills.levels["crafting"] = 4
	sim.tick = 24 * sim.ticks_per_day
	sim.place_instant("workbench", Scen.find_spot(sim, "workbench", sim.colonists.list[0].cell + Vector2i(4, 4), 0))
	sim.ledger.record_produced("plate", 8, "test")
	sim.items.drop(Vector2i(8, 6), "plate", 8)
	sim.ledger.record_produced("refined_essence", 3, "test")
	sim.items.drop(Vector2i(9, 7), "refined_essence", 3)
	var p: Dictionary = {}
	for _i in 2 * sim.ticks_per_day:
		sim.run_ticks(1)
		for q in sim.storyteller.pending:
			if q["kind"] == "fixation":
				p = q
		if not p.is_empty():
			break
	sim.answer_event(int(p["uid"]), true)
	sim.run_ticks(int(sim.defs.fixation["work_ticks"]) + 40)
	assert_eq(_count("fd"), 1, "done once")
	assert_eq(_count("ff"), 0)


func test_feed_one_pa_line_per_regulation_event() -> void:
	var feed := FeedTicker.new()
	var pa := PaBanner.new()
	_owned_nodes.append(feed)
	_owned_nodes.append(pa)
	var sim := make_sim(3, true, 24, 24, _defs(true))
	var d := FeedDirector.new(feed, pa)
	d.bind(sim)
	sim.run_ticks(sim.ticks_per_day + 5)
	assert_eq(pa.pending() + (1 if pa.is_active() else 0), 1, "offered -> one line")
	assert_true(sim.choose_regulation(0, "overtime"))
	assert_eq(pa.pending() + (1 if pa.is_active() else 0), 2, "chosen -> one more")
	assert_eq(feed.line_count(), 0, "not on feed")
	sim.bus.fixation_done.emit(1, "x")
	sim.bus.fixation_failed.emit(1)
	sim.bus.fixation_offered.emit(1, "x")
	assert_eq(pa.pending() + (1 if pa.is_active() else 0), 2, "fixation shows nothing")
