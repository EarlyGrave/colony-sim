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


## Runs a 20-day peaceful bot game; returns {stuck, idle, samples}.
func _run_20_days(sim: Simulation) -> Dictionary:
	var st := {"stuck": 0, "idle": 0, "samples": 0}
	sim.bus.tick_advanced.connect(func(_t: int) -> void:
		for c in sim.colonists.list:
			if not c.alive:
				continue
			st["stuck"] = maxi(st["stuck"], c.stuck_ticks)
			st["samples"] += 1
			if c.job == null and not c.hidden:
				st["idle"] += 1)
	while sim.game_over_reason == "" and sim.tick < 20 * sim.ticks_per_day:
		sim.step()
	return st


func test_20_day_bot_game_no_stuck_conserved_deterministic() -> void:
	var defs := peaceful_defs()
	var a := _build(77, defs)
	var b := _build(77, defs)
	var ra := _run_20_days(a)
	_run_20_days(b)
	assert_lt(ra["stuck"], 100, "a colonist stood still on a path for %d ticks" % ra["stuck"])
	for id in a.defs.items.keys():
		assert_eq(a.items.count_world(id), a.ledger.balance_of(id), "%s not conserved" % id)
	assert_eq(a.tick, b.tick)
	assert_eq(_snapshot(a), _snapshot(b), "20-day runs diverged")
	assert_eq(a.contamination.level, b.contamination.level)
	print("    [20-day] ticks=%d over=%s idle=%.1f%%" % [a.tick, a.game_over_reason, 100.0 * ra["idle"] / maxf(ra["samples"], 1)])
