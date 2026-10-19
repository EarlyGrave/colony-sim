extends TestCase
## I2 The Informant quest: fires from day 12, petition_fee_mult while he reports, three ways out.
## I1 (Cell Block Standing) is not merged here: the informant is injected through InformantMod.informant_fn.

const ID := "q13_informant"


func _defs() -> Defs:
	var d := TestCase.peaceful_defs()
	d.balance["q_enabled"] = true
	return d


func _sim(seed_value: int, with_clerk := true) -> Simulation:
	var sim := make_sim(seed_value, true, 24, 24, _defs())
	var m: InformantMod = sim.quests._modules[ID]
	var inf_id: int = sim.colonists.list[0].id
	m.informant_fn = func() -> int: return inf_id
	if with_clerk and sim.colonists.list.size() > 1:
		sim.colonists.list[1].bio["tag"] = "Clerk"
	return sim


func _days(sim: Simulation, n: int) -> void:
	## Colonies starve around day 9 untended: jump the clock instead of simulating the first 10 days.
	if sim.tick == 0:
		sim.tick = sim.ticks_per_day * 10
		n -= 10
	sim.run_ticks(sim.ticks_per_day * n)


func _mod(sim: Simulation) -> InformantMod:
	return sim.quests._modules[ID]


func test_registered_and_data() -> void:
	var sim := _sim(1)
	assert_true(sim.defs.quests.has(ID))
	assert_true(sim.quests._modules.has(ID))
	assert_eq(_mod(sim).state, "idle")


func test_not_before_day_12() -> void:
	var sim := _sim(2)
	_days(sim, 10)
	assert_eq(_mod(sim).state, "idle")
	assert_eq(sim.quests.mod("petition_fee_mult"), 1.0)


func test_fires_in_at_least_7_of_10_seeds_and_fee_rises() -> void:
	var fired := 0
	for s in range(1, 11):
		var sim := _sim(s)
		_days(sim, 14)
		var m := _mod(sim)
		if m.state != "idle":
			fired += 1
			assert_true(sim.quests.mod("petition_fee_mult") > 1.0, "fee > 1 while he reports (seed %d)" % s)
			assert_true(sim.quests.mod("petition_fee_mult") <= 1.3 + 0.0001)
	assert_true(fired >= 7, "fired %d/10" % fired)


func _offered(seed_value: int, with_clerk := true) -> Simulation:
	var sim := _sim(seed_value, with_clerk)
	_days(sim, 13)
	assert_eq(_mod(sim).state, "offered")
	assert_false(sim.quests.pending_for(ID).is_empty())
	return sim


func test_tolerate_keeps_reports_and_cuts_rations() -> void:
	var sim := _offered(3)
	var before := sim.quests.mod("petition_fee_mult")
	assert_true(sim.answer_quest(int(sim.quests.pending_for(ID)["uid"]), "tolerate"))
	assert_eq(_mod(sim).state, "reporting")
	_days(sim, 3)
	assert_true(sim.quests.mod("petition_fee_mult") > before)
	assert_true(sim.quests.mod("petition_fee_mult") <= 1.3 + 0.0001)
	assert_true(sim.mood.state_of(sim.colonists.list[0]).find("ate_raw") >= 0)


func test_false_info_needs_clerk_and_ends_reports() -> void:
	var sim := _offered(4, false)
	var opts: Array = sim.quests.pending_for(ID)["options"]
	for o: Dictionary in opts:
		if o["id"] == "false_info":
			assert_false(bool(o["enabled"]), "disabled without a Clerk")
	assert_false(sim.answer_quest(int(sim.quests.pending_for(ID)["uid"]), "false_info"))
	var sim2 := _offered(4)
	assert_true(sim2.answer_quest(int(sim2.quests.pending_for(ID)["uid"]), "false_info"))
	assert_eq(_mod(sim2).state, "done")
	assert_eq(sim2.quests.mod("petition_fee_mult"), 1.0)
	_days(sim2, 3)
	assert_eq(sim2.quests.mod("petition_fee_mult"), 1.0)


func test_transfer_removes_worker_and_resets_fee() -> void:
	var sim := _offered(5)
	var inf: Colonist = sim.colonists.list[0]
	assert_true(sim.answer_quest(int(sim.quests.pending_for(ID)["uid"]), "transfer"))
	assert_false(inf.alive)
	assert_true(sim.debt.gone.has(inf.id))
	assert_eq(sim.quests.mod("petition_fee_mult"), 1.0)
	assert_eq(sim.quests.state(ID), "done")


func test_informant_death_ends_quest() -> void:
	var sim := _offered(6)
	sim.colonists.kill(sim.colonists.list[0])
	_days(sim, 1)
	assert_eq(_mod(sim).state, "done")
	assert_eq(sim.quests.mod("petition_fee_mult"), 1.0)
	assert_true(sim.quests.pending_for(ID).is_empty())


func test_debt_cut_still_clamped() -> void:
	var sim := _offered(7)
	assert_eq(QuestLog.MAX_DEBT_CUT_PCT, 2.0)


func test_mid_quest_replay_hash() -> void:
	var a := _offered(8)
	var b := _offered(8)
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b), "same hash mid-quest")
	_days(a, 3)
	_days(b, 3)
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b))
	assert_eq(a.quests.mod("petition_fee_mult"), b.quests.mod("petition_fee_mult"))
