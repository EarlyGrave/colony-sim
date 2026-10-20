extends TestCase
## F5 W4: quest verbs (trait, credit, suspicion, defiance), {dead} placeholder, conds, and the r4 story lines.

const A := "r4_good_behaviour"
const B := "r4_drone_toll"
const C := "r4_quiet_freight"


func _sim(seed_value: int) -> Simulation:
	var sim := Simulation.new(seed_value, make_bus(), peaceful_defs(), {})
	sim.start_new_game()
	_sims.append(sim)
	sim.run_ticks(1)
	_stock(sim, "meal", 60)  # keep the jumped-ahead colony fed
	return sim


## Runs days until the quest has a pending choice, answers it with `pick`; returns the beat answered ("" = none).
func _step(sim: Simulation, q: String, pick: String, max_days := 14) -> String:
	for _d in max_days:
		var p := sim.quests.pending_for(q)
		if p.is_empty():
			sim.run_ticks(sim.ticks_per_day)
			assert_eq(sim.game_over_reason, "", "game over day %d" % sim.day())
			continue
		var beat := str(p["beat"])
		assert_true(sim.answer_quest(int(p["uid"]), pick), "%s %s/%s" % [q, beat, pick])
		return beat
	return ""


func _stock(sim: Simulation, item: String, n: int) -> void:
	var left := n
	var c0 := sim.map_center()
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			if left <= 0:
				return
			var cell := c0 + Vector2i(dx, dy)
			if sim.cell_free_for_items(cell):
				sim.set_zone(cell, "stockpile")
				left -= sim.items.add_at(cell, item, left)


func test_data_loaded_and_text_short() -> void:
	var sim := _sim(1)
	for q in [A, B, C]:
		assert_true(sim.defs.quests.has(q), q)
	var txt := FileAccess.get_file_as_string("res://data/quests_s6.json")
	var re := RegEx.create_from_string('"(?:text|label|hint|title)":\\s*"([^"]*)"')
	for m in re.search_all(txt):
		assert_true(m.get_string(1).length() <= 70, m.get_string(1))
	var pa: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flavor.json"))["pa"]
	for k in ["r4_good_behaviour", "r4_drone_toll", "r4_quiet_freight", "r4_midgame"]:
		# F6W2 re-keyed these per beat: {beat: [lines]}
		var lines: Array = []
		for b: String in (pa[k] as Dictionary):
			lines.append_array(pa[k][b])
		assert_true(lines.size() >= 2, k)
		for l: String in lines:
			assert_true(l.length() <= 70, l)


func test_web_export_fallback_lists_s6() -> void:
	assert_true(FileAccess.get_file_as_string("res://sim/core/defs.gd").contains('"quests_s6.json"'))


func test_trigger_gates() -> void:
	var sim := _sim(2)
	sim.tick = 10 * sim.ticks_per_day
	sim.run_ticks(sim.ticks_per_day)
	assert_eq(sim.quests.state(A), "idle", "no path flag")
	sim.quests.set_flag("path_submit")
	sim.run_ticks(sim.ticks_per_day)
	assert_eq(sim.quests.state(A), "idle", "before min_day 28")
	sim.tick = 28 * sim.ticks_per_day
	sim.run_ticks(sim.ticks_per_day)
	assert_eq(sim.quests.state(A), "active")
	sim.quests.set_flag("path_fight")
	sim.tick = 31 * sim.ticks_per_day
	sim.run_ticks(sim.ticks_per_day)
	assert_eq(sim.quests.state(B), "idle", "needs a repelled raid")
	sim.threats.metro().raids_repelled = 1
	sim.run_ticks(sim.ticks_per_day)
	assert_eq(sim.quests.state(B), "active")


func test_verbs() -> void:
	var sim := _sim(3)
	sim.quests._apply_effects("x", [{"verb": "credit", "n": 7}, {"verb": "suspicion", "n": 12}, {"verb": "defiance", "n": 9}])
	assert_eq(sim.contraband.escape_credit, 7)
	assert_eq(sim.contraband.suspicion, 12.0)
	assert_eq(sim.threats.metro().defiance, 9.0)
	sim.quests._apply_effects("x", [{"verb": "suspicion", "n": -50}, {"verb": "credit", "n": -50}])
	assert_eq(sim.contraband.suspicion, 0.0)
	assert_eq(sim.contraband.escape_credit, 0)
	var n0 := 0
	for c in sim.colonists.list:
		if sim.traits.has(c, "hardened"):
			n0 += 1
	sim.quests._apply_effects("x", [{"verb": "trait", "id": "hardened", "n": 2}])
	var n1 := 0
	for c in sim.colonists.list:
		if sim.traits.has(c, "hardened"):
			n1 += 1
	assert_eq(n1 - n0, 2)


func test_dead_placeholder() -> void:
	var sim := _sim(4)
	assert_eq(sim.quests._w4_text("Seat: {dead}."), "Seat: Inmate 4471.", "static fallback")
	var victim: Colonist = sim.colonists.list[0]
	victim.alive = false
	assert_eq(sim.quests._w4_text("Seat: {dead}."), "Seat: %s." % victim.display_name)
	assert_eq(sim.quests._w4_text("no placeholder"), "no placeholder")


func test_conds() -> void:
	var sim := _sim(5)
	var c: Callable = sim.quests._conds["raids_survived"]
	assert_false(c.call(1), "raids")
	sim.threats.metro().raids_repelled = 2
	assert_true(c.call(2))
	assert_false(sim.quests._conds["defiance_over"].call(10), "defiance0 %s" % sim.threats.metro().defiance)
	sim.threats.metro().add_defiance(20.0)
	assert_true(sim.quests._conds["defiance_over"].call(10))
	var g0 := SocietyConds.gear_owned(sim)
	assert_true(sim.quests._conds["gear_owned"].call(g0))
	assert_false(sim.quests._conds["gear_owned"].call(g0 + 1))
	sim.give_gear(sim.colonists.list[0].id, "rifle", "common")
	assert_true(sim.quests._conds["gear_owned"].call(g0 + 1))


func test_line_a_end_to_end() -> void:
	for pair in [["accept", "strike", "hand_over", "pay"], ["decline", "keep", "hide", "refuse"]]:
		var sim := _sim(6)
		sim.quests.set_flag("path_submit")
		sim.tick = 28 * sim.ticks_per_day
		_stock(sim, "plate", 30)
		sim.give_gear(sim.colonists.list[0].id, str(sim.defs.gear.keys()[1]), "common")
		sim.give_gear(sim.colonists.list[1].id, str(sim.defs.gear.keys()[1]), "common")
		var lifer0 := sim.blocks.standing_of("lifer")
		var beats: Array = []
		for pick: String in pair:
			beats.append(_step(sim, A, pick, 20))
			if beats.size() == 1:
				assert_eq(sim.blocks.standing_of("lifer"), clampf(lifer0 + (5.0 if pick == "accept" else -6.0), 0.0, 100.0), "applied once")
		assert_eq(beats[0], "bonus")
		assert_true(str(beats[1]).begins_with("seats"), str(beats[1]))
		assert_eq(beats[2], "gear")
		assert_eq(beats[3], "recount")
		assert_eq(sim.quests.state(A), "done", str(pair))
		assert_true(sim.quests.flag("r4_bonus") or sim.quests.flag("r4_declined"))
	var s2 := _sim(6)
	s2.quests.set_flag("path_submit")
	s2.tick = 28 * s2.ticks_per_day
	_step(s2, A, "decline", 6)
	assert_true(s2.quests.pending_for(A).is_empty())
	s2.run_ticks(4 * s2.ticks_per_day)
	assert_true(str(s2.quests.pending_for(A)["text"]).contains("Inmate 4471"), "seats text uses fallback name")


func test_line_a_gear_gate() -> void:
	var sim := _sim(7)
	sim.quests.set_flag("path_submit")
	sim.tick = 28 * sim.ticks_per_day
	_step(sim, A, "accept", 6)
	_step(sim, A, "keep", 8)
	for _d in 14:
		if not sim.quests.pending_for(A).is_empty():
			break
		sim.run_ticks(sim.ticks_per_day)
	var opts: Array = sim.quests.pending_for(A)["options"]
	for o: Dictionary in opts:
		if o["id"] == "hand_over":
			assert_false(o["enabled"], "needs gear and plates")


func test_line_b_end_to_end() -> void:
	for picks in [["strip", "interrogate", "stop", "wear"], ["burn", "recruit", "refuse", "cover"], ["strip", "send_back", "stop", "wear"]]:
		var sim := _sim(8)
		sim.quests.set_flag("path_fight")
		sim.threats.metro().raids_repelled = 1
		sim.tick = 30 * sim.ticks_per_day
		_stock(sim, "plate", 20)
		var beats: Array = []
		for pick: String in picks:
			beats.append(_step(sim, B, pick, 20))
		assert_eq(beats, ["wreck", "pilot", "strike_vote", "scars"])
		assert_eq(sim.quests.state(B), "done", str(picks))
	var sim2 := _sim(8)
	sim2.quests.set_flag("path_fight")
	sim2.threats.metro().raids_repelled = 1
	sim2.tick = 30 * sim2.ticks_per_day
	_step(sim2, B, "strip", 6)
	_step(sim2, B, "send_back", 8)
	assert_true(sim2.threats.metro().defiance >= 8.0, "defiance verb applied")
	assert_true(sim2.quests.flag("r4_letter"))
	var sim3 := _sim(8)
	sim3.quests.set_flag("path_fight")
	sim3.threats.metro().raids_repelled = 1
	sim3.tick = 30 * sim3.ticks_per_day
	for pick in ["strip", "send_back", "stop"]:
		_step(sim3, B, pick, 12)
	assert_true(sim3.quests.mod("refine_mult") <= 0.1, "refining crawls")
	sim3.run_ticks(3 * sim3.ticks_per_day)
	assert_eq(sim3.quests.mod("refine_mult"), 1.0, "after 2 days")


func test_line_c_end_to_end() -> void:
	for picks in [["cover", "dump", "refuse", "pass"], ["cover", "open", "accept", "jam"]]:
		var sim := _sim(9)
		sim.quests.set_flag("path_escape")
		sim.tick = 35 * sim.ticks_per_day
		_stock(sim, "plate", 20)
		_stock(sim, "refined_essence", 20)
		var beats: Array = []
		for pick: String in picks:
			beats.append(_step(sim, C, pick, 20))
		assert_eq(beats, ["manifest", "inspection", "courier", "drone_tail"])
		assert_eq(sim.quests.state(C), "done", str(picks))


func test_line_c_sell_needs_roll_call() -> void:
	var sim := _sim(10)
	sim.quests.set_flag("path_escape")
	sim.tick = 35 * sim.ticks_per_day
	for _d in 4:
		sim.run_ticks(sim.ticks_per_day)
	for o: Dictionary in sim.quests.pending_for(C)["options"]:
		if o["id"] == "sell":
			assert_false(o["enabled"], "no Roll Call yet")
	var s2 := _sim(10)
	s2.quests.set_flag("path_escape")
	s2.quests.set_flag("rv_mimic_killed")
	s2.quests.set_flag("rv_colonist_died")
	s2.quests.set_flag("clue_survey_tag")
	s2.tick = 35 * s2.ticks_per_day
	s2.colonists.list[0].alive = false
	_step(s2, C, "sell", 6)
	assert_eq(s2.contraband.escape_credit, 10)
	assert_eq(s2.contraband.suspicion, 6.0)
	assert_true(s2.quests.flag("r4_sold_name"))
