extends TestCase
## QX reconcile: code quests registered with QuestLog, mid-quest replay, stored mods take effect.


func _defs() -> Defs:
	var d := TestCase.peaceful_defs()
	d.balance["q_enabled"] = true
	d.quests["q_selftest"] = ({
		"trigger": {"min_day": 1},
		"beats": {
			"start": {"text": "Test dispatch.", "options": {
				"b": {"label": "B", "effects": [{"verb": "mod", "name": "wave_mult", "value": 0.5, "days": 2.0}], "then": "after"}}},
			"after": {"text": "Later.", "delay_days": 2.0}}})
	return d


func test_modules_registered_and_polled_once() -> void:
	var sim := make_sim(3, true, 24, 24, _defs())
	assert_true(sim.quests._modules.has("q1"))
	assert_true(sim.quests._modules.has("pilgrims_of_the_slag"))
	sim.contamination.level = float(sim.defs.balance["contamination"]["max"]) * 0.5
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_eq(sim.q2_pilgrims.state, "offered")
	assert_eq(sim.quests.state("pilgrims_of_the_slag"), "active")
	var pend := sim.quests.pending_for("pilgrims_of_the_slag")
	assert_false(pend.is_empty())
	assert_true(sim.answer_quest(int(pend["uid"]), "silence"))
	assert_eq(sim.q2_pilgrims.state, "done")
	assert_eq(sim.quests.state("pilgrims_of_the_slag"), "done")
	assert_false(sim.quests.state_parts().is_empty())


func test_mid_quest_replay_same_hash() -> void:
	var defs := _defs()
	var sim := make_sim(7, true, 24, 24, defs)
	var g := 0
	while sim.quests.pending.is_empty() and g < 5 * sim.ticks_per_day:
		sim.step()
		g += 1
	assert_true(sim.answer_quest(int(sim.quests.pending[0]["uid"]), "b"))
	sim.run_ticks(sim.ticks_per_day)
	assert_true(sim.quests.mod("wave_mult") < 1.0)
	var res := SaveGame.load_json(SaveGame.to_json(sim), make_bus(), defs)
	assert_true(bool(res["ok"]))
	var sim2: Simulation = res["sim"]
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))
	sim2.dispose()


func test_audit_and_petition_mods_scale_costs() -> void:
	var sim := make_sim(3, true, 24, 24, _defs())
	var base_a := sim.milestones.required(1)
	var base_p := sim.petition.required(1)
	sim.quests.set_flag("x")
	sim.quests.add_mod("audit_parts_mult", 1.5, 5.0)
	sim.quests.add_mod("petition_fee_mult", 0.5, 5.0)
	var grew := false
	for k: String in base_a:
		if int(sim.milestones.required(1)[k]) > int(base_a[k]):
			grew = true
	assert_true(grew or base_a.is_empty())
	var cut := false
	for k: String in base_p:
		if int(sim.petition.required(1)[k]) < int(base_p[k]):
			cut = true
	assert_true(cut or base_p.is_empty())


func test_refine_mult_slows_refining() -> void:
	var sim := make_sim(3, true, 24, 24, _defs())
	sim.quests.set_flag("x")
	var scen := preload("res://tests/scenario.gd")
	var spot := scen.find_spot(sim, "refinery", sim.map_center() + Vector2i(4, 0), 0)
	var b := sim.place_instant("refinery", spot)
	assert_true(b != null)
	b.recipe = sim.defs.recipes["refine_essence"]
	b.recipe_id = "refine_essence"
	b.input = {"essence_ore": 10}
	var need := int(b.recipe["work_ticks"])
	sim.quests.add_mod("refine_mult", 0.5, 5.0)
	b.progress = 0
	sim.buildings.work(b, need)
	assert_true(b.progress > 0, "half speed: one nominal batch of work is not enough")
