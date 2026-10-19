extends TestCase
## RV: Roll Call (Q15), Lifer's Receipt (Q16), Q14 text, Warden lines, epilogues, first-wave gate.


func _sim() -> Simulation:
	var d := TestCase.peaceful_defs()
	d.balance["q_enabled"] = true
	var sim := make_sim(5, false, 30, 30, d)
	sim.colonists.spawn(Vector2i(4, 4))
	return sim


func _pending(sim: Simulation, q: String) -> Dictionary:
	sim.run_ticks(int(sim.ticks_per_day * 1.5))
	return sim.quests.pending_for(q)


func test_roll_call_options() -> void:
	for opt in ["bury", "burn", "report"]:
		var sim := _sim()
		assert_true(sim.quests.start("q15_roll_call"))
		var p := _pending(sim, "q15_roll_call")
		assert_false(p.is_empty())
		assert_true(sim.quests.flag("clue_our_dead"))
		var before := sim.contamination.level
		assert_true(sim.answer_quest(int(p["uid"]), opt))
		if opt == "bury":
			assert_true(sim.quests.flag("buried_mimic"))
		if opt == "burn":
			assert_true(sim.contamination.level > before)


func test_roll_call_trigger_cond() -> void:
	var sim := _sim()
	var t: Dictionary = (sim.defs.quests["q15_roll_call"]["trigger"] as Dictionary).duplicate()
	assert_eq(int(t["min_day"]), 8)
	t.erase("min_day")
	sim.quests.set_flag("clue_survey_tag")
	assert_false(sim.quests._trigger_ok(t))
	sim.quests.set_flag("rv_mimic_killed")
	assert_true(sim.quests._trigger_ok(t))


func test_receipt() -> void:
	var sim := _sim()
	assert_true(sim.quests.start("q16_lifer_receipt"))
	var p := _pending(sim, "q16_lifer_receipt")
	assert_false(p.is_empty())
	assert_true(sim.answer_quest(int(p["uid"]), "read"))
	assert_true(sim.quests.flag("clue_receipt"))


func test_clues_count_new_flags() -> void:
	var sim := _sim()
	sim.quests.set_flag("clue_our_dead")
	sim.quests.set_flag("clue_receipt")
	assert_true(bool(sim.quests._conds["clues_held"].call(2)))


func test_q14_text() -> void:
	var q: Dictionary = Defs.get_default().quests["q14_three_forms"]
	assert_eq(q["beats"]["land"]["effects"][0]["title"], "Procurator to site")
	assert_true(str(q["beats"]["choose"]["options"]["submit"]["text"]).contains("Keep: nothing."))


func test_lines_and_epilogues() -> void:
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flavor.json"))
	assert_eq((j["warden_lines"] as Array).size(), 20)
	for l: String in j["warden_lines"]:
		assert_true(l.length() <= 70, l)
	for id in ["submit", "fight", "escape", "remission"]:
		assert_true(EndingSystem.epilogue(id).size() >= 5, id)


func test_epilogue_letter_on_win() -> void:
	var sim := _sim()
	var got: Array = []
	sim.bus.letter_received.connect(func(t: String, _x: String) -> void: got.append(t))
	assert_true(sim.endings.mark_won("fight"))
	assert_true(got.has("Collector offline. Quota: unresolved."))


func test_first_wave_gate() -> void:
	var d := TestCase.peaceful_defs()
	d.balance["threat"]["first_wave_gate_days"] = 2.0  # gate ships off (0.0) until a balance pass; test it when on
	var sim := make_sim(5, false, 30, 30, d)
	assert_false(sim.threats._rv_gate_ok())
	sim.bus.first_refine_done.emit()
	assert_true(sim.threats._rv_gate_ok())
