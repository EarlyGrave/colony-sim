extends TestCase
## Quest Q1 (Clerk's Margin Note) against a stub QuestLog.


class StubLog:
	extends RefCounted
	var started: Array = []
	var offers: Array = []
	var flags: Dictionary = {}
	var mods: Dictionary = {}

	func is_enabled() -> bool:
		return true

	func start(id: String) -> void:
		started.append(id)

	func offer(q: String, beat: String, text: String, options: Array) -> void:
		offers.append([q, beat, text, options])

	func set_flag(id: String) -> void:
		flags[id] = true

	func set_mod(name: String, value: float, until: int) -> void:
		mods[name] = [value, until]


func _sim(seed_value := 5) -> Array:
	var d := peaceful_defs()
	d.balance["q_enabled"] = true
	var sim := make_sim(seed_value, true, 24, 24, d)
	for i in 3:
		var f := sim.map_center() + Vector2i(3 + i, 3)
		sim.set_zone(f, "stockpile")
		sim.ledger.record_produced("raw_food", 400, "test")
		sim.items.drop(f, "raw_food", 400)
	sim.run_ticks(1)
	var log := StubLog.new()
	sim.q1_clerk.log_override = log
	var clerk: Colonist = sim.colonists.list[0]
	clerk.bio["tag"] = "Clerk"
	return [sim, log, clerk]


func _days(sim: Simulation, n: int) -> void:
	sim.run_ticks(n * sim.ticks_per_day)


func _pay(sim: Simulation, c: Colonist, n: int) -> void:
	var at := sim.map_center() + Vector2i(3, 1)
	sim.set_zone(at, "stockpile")
	sim.ledger.record_produced("refined_essence", n, "test")
	sim.items.drop(at, "refined_essence", n)
	assert_true(sim.debt.pay(c, n))


func _to_offer(r: Array) -> void:
	var sim: Simulation = r[0]
	_pay(sim, r[2], 1)
	_days(sim, 3)


func test_disabled_by_default() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	assert_eq(sim.q1_clerk.state_parts().size(), 0)
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_eq(sim.q1_clerk.stage, 0)


func test_no_trigger_without_payment_or_tag() -> void:
	var r := _sim()
	_days(r[0], 3)
	assert_eq(r[1].offers.size(), 0)
	assert_eq(r[0].q1_clerk.stage, 0)
	r[2].bio.erase("tag")
	r[0].debt.state_of(r[2]).paid = 1
	_days(r[0], 3)
	assert_eq(r[1].offers.size(), 0)


func test_offer_posts_three_options_once() -> void:
	var r := _sim()
	_to_offer(r)
	_days(r[0], 3)
	assert_eq(r[1].offers.size(), 1)
	assert_eq(r[1].started, ["q1"])
	assert_eq(r[1].offers[0][3].size(), 3)


func test_loophole_is_capped() -> void:
	var r := _sim()
	var sim: Simulation = r[0]
	var clerk: Colonist = r[2]
	_to_offer(r)
	var st := sim.debt.state_of(clerk)
	var before := st.total
	var colony := 0
	for id: int in sim.debt.states:
		colony += sim.debt.states[id].total
	sim.q1_clerk.on_resolved("q1", "loophole")
	var cut := before - st.total
	assert_true(cut >= 0)
	assert_true(cut <= int(before * 0.10))
	assert_true(cut <= int(colony * 0.02))
	assert_true(r[1].mods.has("audit_parts_mult"))
	assert_eq(r[1].mods["audit_parts_mult"][0], 1.2)


func test_loophole_removal_path_is_deterministic() -> void:
	var outs: Array = []
	for i in 2:
		var r := _sim(9)
		_to_offer(r)
		r[0].q1_clerk.on_resolved("q1", "loophole")
		_days(r[0], 4)
		outs.append([r[2].alive, r[0].q1_clerk.removed, r[0].q1_clerk.stage])
	assert_eq(outs[0], outs[1])
	assert_eq(outs[0][2], 4)


func test_loophole_remove_chance_one_removes() -> void:
	var r := _sim()
	var sim: Simulation = r[0]
	sim.q1_clerk.cfg["loophole"]["remove_chance"] = 1.0
	_to_offer(r)
	sim.q1_clerk.on_resolved("q1", "loophole")
	_days(sim, 4)
	assert_false(r[2].alive)
	assert_true(sim.q1_clerk.removed)


func test_report_gives_allowance_and_mood() -> void:
	var r := _sim()
	var sim: Simulation = r[0]
	sim.q1_clerk.cfg["report"]["escape_chance"] = 0.0
	_to_offer(r)
	var st := sim.debt.state_of(r[2])
	var total := st.total
	var had := sim.items.count_stored("refined_essence")
	sim.q1_clerk.on_resolved("q1", "report")
	assert_eq(st.total, total)
	assert_true(sim.items.count_stored("refined_essence") >= had)
	assert_true(sim.mood.state_of(r[2]).find("clerk_reported") >= 0)
	assert_true(r[2].alive)


func test_report_may_escape() -> void:
	var r := _sim()
	var sim: Simulation = r[0]
	sim.q1_clerk.cfg["report"]["escape_chance"] = 1.0
	_to_offer(r)
	sim.q1_clerk.on_resolved("q1", "report")
	assert_false(r[2].alive)
	assert_eq(sim.debt.gone[r[2].id], "escaped")


func test_ignore_sets_clue_flag_and_letter() -> void:
	var r := _sim()
	var sim: Simulation = r[0]
	var letters: Array = []
	sim.bus.letter_received.connect(func(t: String, _x: String) -> void: letters.append(t))
	_to_offer(r)
	sim.q1_clerk.on_resolved("q1", "ignore")
	assert_true(r[1].flags.has("clue_clause"))
	_days(sim, 6)
	assert_true(letters.has("Overheard"))
	assert_true(r[2].alive)
	assert_eq(sim.q1_clerk.stage, 4)


func test_generator_tags_only_when_enabled() -> void:
	var offd := peaceful_defs()
	offd.balance["q_enabled"] = false
	var off := make_sim(5, true, 24, 24, offd)
	for i in 9:
		var c := ColonistGenerator.generate(off, Vector2i(3, 3))
		assert_false(c.bio.has("tag"))
	var d := peaceful_defs()
	d.balance["q_enabled"] = true
	var on := make_sim(5, true, 24, 24, d)
	var tagged := 0
	for i in 9:
		if ColonistGenerator.generate(on, Vector2i(3, 3)).bio.has("tag"):
			tagged += 1
	assert_true(tagged >= 1)
