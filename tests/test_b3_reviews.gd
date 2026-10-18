extends TestCase
## B3: Parole Reviews and the auto_throttle_above rule (all gated by balance "b3").


func _defs(on: bool) -> Defs:
	var d := peaceful_defs()
	d.balance["b3"] = {"enabled": on}
	return d


func _run(on: bool) -> Simulation:
	var sim := make_sim(3, false, 24, 24, _defs(on))
	sim.colonists.spawn(Vector2i(4, 4))
	sim.run_ticks(1)
	sim.milestones.waves_repelled = 3
	sim.milestones.done_tiers = [0, 1, 2, 3]
	for c in sim.colonists.list:
		var st: DebtState = sim.debt.state_of(c)
		st.paid = st.total
	sim.run_ticks(Simulation.TICKS_PER_SECOND * 4)
	return sim


func test_gate_off_and_on_by_default() -> void:
	assert_true(bool(Defs.get_default().balance["b3"]["enabled"]))
	var sim := _run(false)
	assert_eq(sim.milestones.reviews_done.size(), 0)


func test_reviews_complete_in_order() -> void:
	var sim := _run(true)
	assert_eq(sim.milestones.reviews_done.size(), 3)
	assert_eq(sim.milestones.reviews_done[0], "review_1")


func test_reviews_deterministic() -> void:
	assert_eq(SaveGame.state_hash(_run(true)), SaveGame.state_hash(_run(true)))


func test_throttle_rule() -> void:
	var sim := make_sim(3, false, 24, 24, _defs(true))
	sim.contamination.level = float(sim.defs.balance["contamination"]["max"]) * 0.9
	assert_false(sim.buildings.refining_capped())
	sim.set_rule("auto_throttle_above", true)
	assert_true(sim.buildings.refining_capped())


func _evac_sim(rule_on: bool, hp_frac: float) -> Simulation:
	var sim := make_sim(3, false, 24, 24, _defs(true))
	var hq: Building = sim.buildings.place("hq", Vector2i(10, 10), false)
	hq.hp = hq.max_hp * hp_frac
	sim.colonists.spawn(Vector2i(4, 4))
	if rule_on:
		sim.set_rule("evacuate_low_hq", true)
	sim.set_alarm(true)
	sim.run_ticks(Simulation.TICKS_PER_SECOND * 2)
	return sim


func _sheltering(sim: Simulation) -> bool:
	for c in sim.colonists.list:
		if c.hidden or (c.job != null and c.job.type == "flee"):
			return true
	return false


func test_evacuate_low_hq_rule() -> void:
	assert_true(_sheltering(_evac_sim(false, 0.3)), "rule off: hides in the hurt HQ")
	assert_true(_sheltering(_evac_sim(true, 0.9)), "healthy HQ stays a shelter")
	assert_false(_sheltering(_evac_sim(true, 0.3)), "rule on: hurt HQ is evacuated")
