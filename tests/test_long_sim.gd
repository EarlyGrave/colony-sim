extends TestCase
## Long soak: 10000 ticks conserve items and are deterministic for equal seeds.

const Scenario := preload("res://tests/scenario.gd")


func _build(seed_value: int, defs: Defs) -> Simulation:
	var sim := make_sim(seed_value, true, 24, 24, defs)
	Scenario.standard_colony(sim, 0)
	return sim


func _snapshot(sim: Simulation) -> Dictionary:
	var counts := {}
	for id in sim.defs.items.keys():
		counts[id] = sim.items.count_world(id)
	return counts


func test_10000_ticks_conserve_items_and_determinism() -> void:
	var defs := peaceful_defs()
	var a := _build(21, defs)
	var b := _build(21, defs)
	for i in 10:
		a.run_ticks(1000)
		b.run_ticks(1000)
		for id in a.defs.items.keys():
			assert_eq(a.items.count_world(id), a.ledger.balance_of(id), "%s not conserved at tick %d" % [id, a.tick])
	assert_gt(a.tick, 5000, "colony should survive a long peaceful stretch (planet death may end it)")
	assert_eq(a.tick, b.tick, "tick mismatch")
	assert_eq(_snapshot(a), _snapshot(b), "item counts diverged between identical sims")
	assert_gt(a.ledger.get_count("mining:essence_ore"), 0, "nothing was mined")
