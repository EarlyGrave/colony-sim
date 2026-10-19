extends TestCase
## W1: society conds + S1 Cohesion Fee.

const ID := "s1_cohesion_fee"


func _sim(seed_value: int) -> Simulation:
	var d := TestCase.peaceful_defs()
	d.balance["q_enabled"] = true
	return make_sim(seed_value, true, 24, 24, d)


func _low(sim: Simulation, block := "clerk") -> void:
	sim.blocks.standing[block] = 20.0


func _to_day15(sim: Simulation, days := 2) -> void:
	sim.tick = sim.ticks_per_day * 14
	sim.run_ticks(sim.ticks_per_day * days)


func _stock(sim: Simulation, n: int) -> void:
	var at := sim.map_center() + Vector2i(3, 1)
	sim.set_zone(at, "stockpile")
	sim.ledger.record_produced("refined_essence", n, "test")
	sim.items.drop(at, "refined_essence", n)


## Sim with S1 offered and the 'ask' choice pending.
func _offered(seed_value: int) -> Simulation:
	var sim := _sim(seed_value)
	_low(sim)
	_stock(sim, 30)
	_to_day15(sim, 1)
	sim.run_ticks(sim.ticks_per_day * 2)
	return sim


func test_conds_true_false() -> void:
	var sim := _sim(1)
	var q := sim.quests
	assert_false(q._trigger_ok({"block_standing_below": {"block": "any", "v": 30}}))
	_low(sim)
	assert_true(q._trigger_ok({"block_standing_below": {"block": "any", "v": 30}}))
	assert_true(q._trigger_ok({"block_standing_below": {"block": "clerk", "v": 30}}))
	assert_false(q._trigger_ok({"block_standing_below": {"block": "lifer", "v": 30}}))
	assert_false(q._trigger_ok({"block_standing_above": {"block": "any", "v": 70}}))
	sim.blocks.standing["lifer"] = 90.0
	assert_true(q._trigger_ok({"block_standing_above": {"block": "any", "v": 70}}))
	assert_false(q._trigger_ok({"contraband_stash_over": 6}))
	sim.contraband.stash[sim.colonists.list[0].id] = 9
	assert_eq(q._trigger_ok({"contraband_stash_over": 6}), sim.contraband.is_enabled())


func test_conds_missing_systems() -> void:
	var sim := _sim(2)
	sim.blocks = null
	sim.contraband = null
	assert_false(SocietyConds.standing_cmp(sim, {"block": "any", "v": 30}, true))
	assert_false(SocietyConds.stash_over(sim, 1))
	assert_false(SocietyConds.informant_alive(sim))
	assert_eq(SocietyConds.lowest_block(sim), "")


func test_informant_alive_cond() -> void:
	var sim := _sim(3)
	var c: Colonist = sim.colonists.list[0]
	sim.blocks._informant_id = c.id
	assert_true(SocietyConds.informant_alive(sim))
	c.alive = false
	assert_false(SocietyConds.informant_alive(sim))


func test_not_before_day_15() -> void:
	var sim := _sim(4)
	_low(sim)
	sim.tick = sim.ticks_per_day * 10
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_eq(sim.quests.state(ID), "idle")


func test_starts_in_7_of_10_seeds() -> void:
	var n := 0
	for s in range(1, 11):
		var sim := _sim(s)
		_low(sim)
		_to_day15(sim)
		if sim.quests.state(ID) != "idle":
			n += 1
	assert_true(n >= 7, "started %d/10" % n)


func test_pay() -> void:
	var sim := _offered(5)
	var p := sim.quests.pending_for(ID)
	assert_false(p.is_empty())
	var before := sim.blocks.standing_of("clerk")
	var refined := sim.items.count_stored("refined_essence")
	assert_true(sim.quests.answer(int(p["uid"]), "pay"))
	assert_true(sim.quests.flag("block_covered"))
	assert_true(sim.blocks.standing_of("clerk") >= before + 9.0)
	assert_eq(sim.items.count_stored("refined_essence"), refined - 15)
	assert_eq(sim.quests.state(ID), "done")


func test_refuse() -> void:
	var sim := _offered(6)
	var p := sim.quests.pending_for(ID)
	assert_true(sim.quests.answer(int(p["uid"]), "refuse"))
	assert_true(sim.quests.mod("petition_fee_mult") > 1.0)
	var hit := 0
	for c in sim.colonists.list:
		if c.alive and sim.blocks.block_of(c) == "clerk" and sim.mood.state_of(c).find("left_to_ledger") >= 0:
			hit += 1
	assert_true(hit > 0)


func test_redirect_and_debt_cap() -> void:
	var sim := _offered(7)
	var lifer: Colonist = null
	for c in sim.colonists.list:
		if c.alive and sim.blocks.block_of(c) == "lifer":
			lifer = c
			break
	assert_true(lifer != null)
	var st := sim.debt.state_of(lifer)
	var before := st.total
	var total_before := 0
	for c in sim.colonists.list:
		total_before += sim.debt.state_of(c).total
	var p := sim.quests.pending_for(ID)
	assert_true(sim.quests.answer(int(p["uid"]), "redirect"))
	assert_true(st.total > before)
	var total_after := 0
	for c in sim.colonists.list:
		total_after += sim.debt.state_of(c).total
	assert_true(float(total_after - total_before) <= total_before * 0.02 + 1.0, "debt change within cap")


func test_replay_hash_equal() -> void:
	var a := _offered(8)
	var b := _offered(8)
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b))
