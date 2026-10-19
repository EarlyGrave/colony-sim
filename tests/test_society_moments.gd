extends TestCase
## N3 society moments: M1 Debt of the Dead, M2 Informant Succession, M3 Walkout, verb `path`, cond `clues_held`.


func _sim(seed_value := 5) -> Simulation:
	var d := peaceful_defs()
	d.debt["grace_days"] = 0
	var sim := make_sim(seed_value, true, 24, 24, d)
	sim.run_ticks(1)
	for i in 6:
		sim.colonists.add(ColonistGenerator.generate(sim, sim.map_center() + Vector2i(i, -2)))
	sim.run_ticks(1)
	return sim


func _letters(sim: Simulation) -> Array:
	var out: Array = []
	sim.bus.letter_received.connect(func(t: String, _x: String) -> void: out.append(t))
	return out


func _with_block(sim: Simulation, b: String) -> Array[Colonist]:
	var out: Array[Colonist] = []
	for c in sim.colonists.list:
		if c.alive and sim.blocks.block_of(c) == b:
			out.append(c)
	return out


func test_m1_debt_moves_to_block_and_fight_waives() -> void:
	for fight in [false, true]:
		var sim := _sim()
		if fight:
			sim.quests.set_flag("path_fight")
		var ls := _letters(sim)
		var mem := _with_block(sim, "lifer")
		assert_true(mem.size() >= 2, "lifer block has two members")
		var dead := mem[0]
		var other := mem[1]
		var before := sim.debt.state_of(other).total
		var cap := ceili(sim.debt.state_of(other).remaining() * 0.01)
		sim.colonists.kill(dead)
		var delta := sim.debt.state_of(other).total - before
		if fight:
			assert_eq(delta, 0, "fight path waives")
		else:
			assert_true(delta > 0 and delta <= cap, "moved <= 1%% cap (%d)" % delta)
			assert_true(ls.has("Debt of the dead"), "letter")


func test_m2_succession_once() -> void:
	var sim := _sim()
	sim.run_ticks(sim.ticks_per_day)
	var old := sim.blocks.informant_id()
	assert_true(old != 0, "informant picked")
	sim.blocks.standing["clerk"] = 90.0
	var ls := _letters(sim)
	sim.colonists.kill(sim.colonists.get_by_id(old))
	sim.run_ticks(sim.ticks_per_day)
	var nw := sim.blocks.informant_id()
	assert_true(nw != old and nw != 0, "new informant appointed")
	assert_true(sim.quests.flag("informant_succeeded"), "flag")
	assert_true(ls.has("Promotion"), "letter")
	sim.colonists.kill(sim.colonists.get_by_id(nw))
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_eq(sim.blocks.informant_id(), nw, "no second succession")


func _low(sim: Simulation) -> void:
	for _d in 4:
		sim.blocks.standing["zealot"] = 5.0
		sim.run_ticks(sim.ticks_per_day)


func test_m3_walkout_unmet_escapes() -> void:
	var sim := _sim()
	var ls := _letters(sim)
	_low(sim)
	assert_true(ls.has("Ultimatum"), "ultimatum issued")
	for _d in 3:
		sim.blocks.standing["zealot"] = 5.0
		sim.run_ticks(sim.ticks_per_day)
	assert_true(ls.has("Walkout"), "walkout after deadline")


func test_m3_walkout_met_gains_20() -> void:
	var sim := _sim()
	var ls := _letters(sim)
	_low(sim)
	assert_true(ls.has("Ultimatum"), "ultimatum issued")
	for c in _with_block(sim, "zealot"):
		sim.debt.state_of(c).period_paid = 99
	sim.blocks.standing["zealot"] = 10.0
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_true(ls.has("Ultimatum withdrawn"), "met")
	assert_true(sim.blocks.standing["zealot"] >= 25.0, "+20 standing (%f)" % sim.blocks.standing["zealot"])


func test_path_verb_shifts_standing_per_data() -> void:
	for id in ["submit", "fight", "escape"]:
		var s2 := _sim()
		var lean: Dictionary = s2.blocks.cfg["leaning"]
		var d := float(s2.blocks.cfg["leaning_delta"])
		s2.quests._apply_effects("x", [{"verb": "path", "id": id}])
		assert_true(s2.quests.flag("path_" + id), "flag " + id)
		for b: String in lean:
			var l := int(lean[b][id])
			assert_eq(s2.blocks.standing[b], clampf(50.0 + l * d, 0.0, 100.0), "%s/%s" % [b, id])


func test_clues_held_cond() -> void:
	var sim := _sim()
	var fn: Callable = sim.quests._conds["clues_held"]
	assert_false(bool(fn.call(2)), "none")
	sim.quests.set_flag("clue_manifest")
	sim.quests.set_flag("clue_buyer")
	assert_true(bool(fn.call(2)), "two")
	assert_false(bool(fn.call(3)), "not three")
