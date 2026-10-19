extends TestCase
## CD: quest mod despair_mult scales DebtSystem despair gain (default 1.0 = unchanged).


func _gain(mult: float) -> float:
	var d := peaceful_defs()
	d.debt["grace_days"] = 0
	d.debt["due_days"] = 1
	var sim := make_sim(5, true, 24, 24, d)
	if mult != 1.0:
		sim.quests.add_mod("despair_mult", mult, 5.0)
	sim.run_ticks(sim.ticks_per_day * 4)
	var total := 0.0
	for id: int in sim.debt.states:
		total += sim.debt.states[id].despair
	return total


func test_default_is_one() -> void:
	var sim := make_sim(5)
	assert_eq(sim.quests.mod("despair_mult"), 1.0)


func test_mod_scales_gain() -> void:
	var base := _gain(1.0)
	assert_gt(base, 0.0, "despair accrues without payment")
	assert_lt(_gain(0.5), base)
