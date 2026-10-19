extends TestCase
## N1 story data: Q14 Three Forms (+Q14b), S4a/S4b, S5, text length.

const Q14 := "q14_three_forms"


func _sim(seed_value: int, sentence := 1) -> Simulation:
	var sim := Simulation.new(seed_value, make_bus(), peaceful_defs(), {"sentence": sentence})
	sim.start_new_game()
	_sims.append(sim)
	sim.run_ticks(1)
	return sim


func _run_until_pending(sim: Simulation, q: String, days: int) -> Dictionary:
	for _d in days:
		sim.run_ticks(sim.ticks_per_day)
		var p := sim.quests.pending_for(q)
		if not p.is_empty():
			return p
	return {}


func _q14_offered(seed_value: int) -> Simulation:
	var sim := _sim(seed_value)
	sim.quests.set_flag("clue_manifest")
	sim.quests.set_flag("clue_warden_quota")
	sim.tick = 29 * sim.ticks_per_day
	var p := _run_until_pending(sim, Q14, 36)
	return sim if not p.is_empty() else null


func test_q14_fires_10_seeds() -> void:
	for s in range(1, 11):
		assert_true(_q14_offered(s) != null, "Q14 offered seed %d" % s)


func test_q14_needs_two_clues() -> void:
	var sim := _sim(2)
	sim.quests.set_flag("clue_manifest")
	sim.tick = 29 * sim.ticks_per_day
	assert_true(_run_until_pending(sim, Q14, 36).is_empty(), "one clue is not enough")


func test_q14_paths() -> void:
	var lean := {"submit": {"lifer": 1, "zealot": -1}, "fight": {"zealot": 1, "clerk": -1}, "escape": {"lifer": -1}}
	for pid: String in lean:
		var sim := _q14_offered(4)
		var before: Dictionary = sim.blocks.standing.duplicate()
		assert_true(sim.answer_quest(int(sim.quests.pending_for(Q14)["uid"]), pid))
		assert_true(sim.quests.flag("path_" + pid), "flag " + pid)
		assert_eq(sim.endings.path(), pid)
		for b: String in lean[pid]:
			assert_eq(sim.blocks.standing_of(b), clampf(float(before[b]) + 15.0 * int(lean[pid][b]), 0.0, 100.0), "%s %s" % [pid, b])
		assert_eq(sim.quests.state(Q14), "done")


func test_q14b_amend_once() -> void:
	var sim := _q14_offered(4)
	sim.answer_quest(int(sim.quests.pending_for(Q14)["uid"]), "submit")
	var cell: Vector2i = sim.storyteller._free_cell_near(sim.map_center(), 3)
	sim.set_zone(cell, "stockpile")
	sim.items.add_at(cell, "refined_essence", 30)
	sim.tick = 44 * sim.ticks_per_day
	var p := _run_until_pending(sim, "q14b_amended_form", 3)
	assert_true(not p.is_empty(), "Q14b offered")
	var z := sim.blocks.standing_of("zealot")
	assert_true(sim.answer_quest(int(p["uid"]), "to_fight"))
	assert_eq(sim.endings.path(), "fight")
	assert_true(not sim.quests.flag("path_submit"), "old path cleared")
	assert_eq(sim.blocks.standing_of("zealot"), clampf(clampf(z - 20.0, 0.0, 100.0) + 15.0, 0.0, 100.0))
	assert_eq(sim.items.count_stored("refined_essence"), 10)


func _s4a(seed_value: int) -> Simulation:
	var sim := _sim(seed_value)
	sim.quests.set_flag("installment_missed")
	sim.tick = 19 * sim.ticks_per_day
	for _d in 3:
		sim.run_ticks(sim.ticks_per_day)
	return sim


func test_s4a_sets_contraband_on() -> void:
	var sim := _s4a(3)
	assert_true(sim.quests.flag("contraband_on"))
	assert_eq(sim.quests.state("s4a_unaccounted_essence"), "done")


func test_s4b_options() -> void:
	for opt: String in ["shakedown", "ride", "turn_in"]:
		var sim := _s4a(3)
		sim.contraband.cfg["enabled"] = true  # stands in for N2's contraband_on flag check
		sim.contraband.cfg["blackmarket_stash"] = 99
		sim.contraband.stash[1] = 9
		var p := _run_until_pending(sim, "s4b_stash_inventory", 3)
		assert_true(not p.is_empty(), "S4b offered")
		var lifer := sim.blocks.standing_of("lifer")
		assert_true(sim.answer_quest(int(p["uid"]), opt))
		match opt:
			"ride":
				assert_true(sim.quests.flag("clue_buyer"))
			"turn_in":
				assert_true(sim.quests.flag("warden_favor"))
				assert_eq(sim.blocks.standing_of("lifer"), lifer - 15.0)
			_:
				assert_true(sim.quests.flag("shaken_down"))


func test_s5_ng_only() -> void:
	var sim := _sim(3)
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_eq(sim.quests.state("s5_old_cells"), "idle", "not in sentence 1")
	var sim2 := _sim(3, 2)
	sim2.run_ticks(sim2.ticks_per_day * 2)
	assert_eq(sim2.quests.state("s5_old_cells"), "done")


func test_text_lengths() -> void:
	var sim := _sim(1)
	for q in ["q14_three_forms", "q14b_amended_form", "s4a_unaccounted_essence", "s4b_stash_inventory", "s5_old_cells"]:
		assert_true(sim.defs.quests.has(q), q)
		for bid: String in sim.defs.quests[q]["beats"]:
			var b: Dictionary = sim.defs.quests[q]["beats"][bid]
			for o: Dictionary in b.get("options", {}).values():
				assert_true(str(o["label"]).length() <= 70 and str(o["hint"]).length() <= 70, q + " " + str(o["label"]))
	var pa: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flavor.json"))["pa"]
	for k in ["path_submit", "path_fight", "path_escape"]:
		assert_true((pa[k] as Array).size() >= 2, k)
