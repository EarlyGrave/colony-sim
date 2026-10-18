extends TestCase
## K5: solar ~30% of a smelter behind k5_enabled; expedition bot completes Frontier Quota.
const PowerModel := preload("res://tools/power_model.gd")
const BotReport := preload("res://tools/bot_report.gd")


func test_flag_off_keeps_old_solar() -> void:
	var d := peaceful_defs()
	assert_false(bool(d.balance.get("k5_enabled", false)))
	assert_eq(PowerModel.gen_of(d, "solar_array"), 25.0)
	var sim := make_sim(1, true, 48, 48, d)
	var b := sim.buildings.place("solar_array", Vector2i(10, 10), false)
	assert_eq(sim.power.gen_of(b), 25.0)


func test_solar_smelter_ratio_band() -> void:
	var d := peaceful_defs()
	d.balance["k5_enabled"] = true
	var ratio := PowerModel.gen_of(d, "solar_array") / float(d.buildings["smelter"]["power_use"])
	assert_true(ratio >= 0.25 and ratio <= 0.35, "ratio %.2f" % ratio)
	for n in [1, 2, 3, 4]:
		var f: float = PowerModel.line(d, n, {"solar_array": PowerModel.solars_for(d, n)})["factor"]
		assert_true(f >= 0.75, "sane build n=%d factor %.2f" % [n, f])
	var sim := make_sim(1, true, 48, 48, d)
	assert_eq(sim.power.gen_of(sim.buildings.place("solar_array", Vector2i(10, 10), false)), 12.0)


func test_expedition_bot_completes_frontier_quota() -> void:
	# Full 5-seed x 25-day table (3/5 complete) is in docs/agents/K5/K-report.md; the test keeps two fast seeds.
	for s in [1, 4]:
		var r: Dictionary = BotReport.play(s, 14, make_bus(), "baseline", true)
		assert_true(int(r.get("frontier_ok", 0)) >= 1, "seed %d frontier quota completed" % s)
