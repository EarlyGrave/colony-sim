extends TestCase
## R2 Q8 What the Creatures Wear: def loads, trigger, option effects, quest-only mimic spawn.

const Q := "q8_creatures_wear"


func _sim(seed_value := 5) -> Simulation:
	var d := TestCase.peaceful_defs()
	d.balance["q_enabled"] = true
	var sim := make_sim(seed_value, false, 30, 30, d)
	sim.colonists.spawn(Vector2i(4, 4))
	return sim


func _opts(sim: Simulation) -> Dictionary:
	return sim.defs.quests[Q]["beats"]["nest"]["options"]


func _at_nest(sim: Simulation) -> void:
	assert_true(sim.quests.start(Q))
	sim.run_ticks(int(sim.ticks_per_day * 2.5))
	assert_false(sim.quests.pending_for(Q).is_empty())


func test_defs_load() -> void:
	var d := Defs.get_default()
	assert_true(d.quests.has(Q))
	assert_eq(int(d.quests[Q]["trigger"]["pollution_over"]), 70)
	assert_eq(str(d.quests[Q]["trigger"]["quest_done"]), "pilgrims_of_the_slag")
	assert_true(d.enemies.has("mimic"))
	assert_true(float(d.enemies["mimic"]["max_hp"]) > 0.0)
	assert_eq(str(d.enemies["mimic"]["sprite"]), "crawler")


func test_mimic_not_in_raids() -> void:
	var d := Defs.get_default()
	for id: String in d.raids:
		if d.raids[id].has("units"):
			for u: Dictionary in d.raids[id]["units"]:
				assert_true(str(u["enemy"]) != "mimic")


func test_feed() -> void:
	var sim := _sim()
	var before := sim.contamination.level
	_at_nest(sim)
	assert_true(sim.answer_quest(int(sim.quests.pending_for(Q)["uid"]), "feed"))
	assert_eq(sim.quests.mod("wave_mult"), 0.5)
	assert_true(sim.contamination.level > before)


func test_cleanse_requires_plates_and_cuts_pollution() -> void:
	var sim := _sim()
	sim.contamination.level = 80.0
	var o: Dictionary = _opts(sim)["cleanse"]
	assert_false(sim.quests._requires_ok(o["requires"]))
	sim.quests._apply_effects(Q, [{"verb": "pollution", "value": -0.15}])
	assert_near(sim.contamination.level, 65.0, 0.01)
	assert_eq(int(o["effects"][0]["n"]), -40)


func test_study_flag_mod_and_mimic_spawn() -> void:
	var sim := _sim()
	_at_nest(sim)
	assert_true(sim.answer_quest(int(sim.quests.pending_for(Q)["uid"]), "study"))
	assert_true(sim.quests.flag("clue_survey_tag"))
	assert_eq(sim.quests.mod("essence_drop_mult"), 2.0)
	assert_eq(sim.threats.enemies.size(), 1)
	assert_eq(sim.threats.enemies[0].def_id, "mimic")


func test_no_mimic_without_quest() -> void:
	var sim := make_sim(5, false, 30, 30, TestCase.peaceful_defs())
	sim.run_ticks(sim.ticks_per_day)
	for e in sim.threats.enemies:
		assert_true(e.def_id != "mimic")
