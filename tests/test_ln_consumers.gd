extends TestCase
## LN: consumers for the stored quest mods essence_drop_mult (Q8) and review_sponsored (Q3).


func _sim() -> Simulation:
	var d := TestCase.peaceful_defs()
	d.balance["q_enabled"] = true
	var sim := make_sim(5, false, 30, 30, d)
	sim.colonists.spawn(Vector2i(4, 4))
	return sim


func _kill_one(sim: Simulation) -> int:
	var e: Enemy = sim.threats._spawn("mimic", Vector2i(10, 10))
	var before := sim.ledger.get_count("creature:essence_ore")
	sim.threats.damage_enemy(e, 9999.0)
	return sim.ledger.get_count("creature:essence_ore") - before


func test_kill_drops_nothing_by_default() -> void:
	var sim := _sim()
	sim.quests.set_flag("x")
	assert_eq(_kill_one(sim), 0)


func test_essence_drop_mult_doubles_yield() -> void:
	var sim := _sim()
	sim.quests.set_flag("x")
	sim.quests.set_mod("essence_drop_mult", 2.0, 2.0)
	assert_eq(_kill_one(sim), 1)
	assert_true(sim.items.count_world("essence_ore") >= 1)


func test_sponsored_review_counts_sooner_and_is_consumed() -> void:
	var sim := _sim()
	sim.run_ticks(1)
	sim.milestones.done_tiers = [0, 1, 2, 3]
	var r := sim.milestones.current_review()
	var base := sim.milestones.review_progress(r)
	sim.quests.set_flag("review_sponsored")
	assert_true(sim.milestones._sponsored_progress(r) >= base)
	for c in sim.colonists.list:
		var st: DebtState = sim.debt.state_of(c)
		st.paid = st.total
	sim.milestones.waves_repelled = 3
	sim.run_ticks(Simulation.TICKS_PER_SECOND * 4)
	assert_true(sim.milestones.reviews_done.size() >= 1)
	assert_false(sim.quests.flag("review_sponsored"))
