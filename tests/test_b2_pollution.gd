extends TestCase
## B2: idle decay, throttle reward, clean-outpost targeting, clean contract discount (all behind b2 keys).

const Scenario := preload("res://tests/scenario.gd")


func _defs(on: bool) -> Defs:
	var d := peaceful_defs()
	d.balance["b2_pollution"]["enabled"] = on
	d.threat["b2_clean_outpost"]["enabled"] = on
	return d


func _run(on: bool, throttle: bool) -> float:
	var sim := make_sim(3, true, 24, 24, _defs(on))
	sim.contamination.level = 40.0
	if throttle:
		sim.set_rule("refine_cap", true)
	for i in sim.ticks_per_day:
		sim.step()
	return sim.contamination.level


func test_on_by_default_and_off_switch() -> void:
	assert_true(bool(Defs.get_default().balance["b2_pollution"]["enabled"]))
	assert_true(bool(Defs.get_default().threat["b2_clean_outpost"]["enabled"]))
	assert_true(_run(false, false) >= 39.99, "no decay when off")


func test_idle_decay_and_throttle_reward() -> void:
	var plain := _run(true, false)
	var thr := _run(true, true)
	assert_true(plain < 39.9, "idle planet heals")
	assert_true(thr < plain - 0.5, "throttle heals faster")


func test_clean_contract_discount() -> void:
	var sim := make_sim(3, true, 24, 24, _defs(true))
	var c := {"essence": 10}
	assert_eq(sim.contracts.required_essence(c), 9, "10 -> ceil(8.5)")
	sim.contamination.level = 80.0
	assert_eq(sim.contracts.required_essence(c), 10, "dirty planet: no discount")


func test_clean_outposts_ignored() -> void:
	var sim := make_sim(3, true, 24, 24, _defs(true))
	var b := sim.buildings.place("miner", Scenario.find_spot(sim, "miner", sim.map_center() + Vector2i(4, 4), 0), false)
	assert_true(b != null)
	if b == null:
		return
	sim.contamination.level = 5.0
	assert_true(sim.threats.model._b2_ignores(b))
	sim.contamination.level = 60.0
	assert_true(not sim.threats.model._b2_ignores(b))
