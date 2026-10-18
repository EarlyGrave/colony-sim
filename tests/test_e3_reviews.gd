extends TestCase
## E3: Chain Gang Review (Parole Reviews 4-5), gated by balance "e3_enabled".


func _sim(on: bool) -> Simulation:
	var d := peaceful_defs()
	d.balance["e3_enabled"] = on
	d.balance["k2_enabled"] = false
	var sim := make_sim(3, false, 24, 24, d)
	sim.colonists.spawn(Vector2i(4, 4))
	sim.run_ticks(1)
	sim.milestones.waves_repelled = 3
	sim.milestones.done_tiers = [0, 1, 2, 3]
	return sim


func _pay(sim: Simulation, frac: float) -> void:
	for c in sim.colonists.list:
		var st: DebtState = sim.debt.state_of(c)
		st.paid = int(st.total * frac)


func test_off_by_default_and_no_extra_reviews() -> void:
	var sim := _sim(false)
	_pay(sim, 1.0)
	sim.run_ticks(Simulation.TICKS_PER_SECOND * 6)
	assert_eq(sim.milestones.reviews_done.size(), 3)
	assert_eq(sim.milestones.e3_rank_title(), "")


func test_review_4_needs_debt_below_75_pct() -> void:
	var sim := _sim(true)
	_pay(sim, 0.2)
	sim.run_ticks(Simulation.TICKS_PER_SECOND * 6)
	assert_eq(sim.milestones.reviews_done.size(), 3)
	_pay(sim, 0.3)
	sim.run_ticks(Simulation.TICKS_PER_SECOND * 2)
	assert_true(sim.milestones.reviews_done.has("e3_review_4"))
	assert_eq(sim.milestones.e3_audit_bonus_days(), 1.0)
	assert_eq(sim.milestones.e3_rank_title(), "Trusted Inmate")


func test_range_score_zero_without_power() -> void:
	var sim := _sim(true)
	assert_eq(sim.milestones.e3_range_score(), 0.0)
	_pay(sim, 1.0)
	sim.run_ticks(Simulation.TICKS_PER_SECOND * 6)
	assert_false(sim.milestones.reviews_done.has("e3_review_5"))
