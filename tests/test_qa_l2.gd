extends TestCase
## L5: the logistics-2 QA bot profile ("power") runs without script errors and degrades to a no-op
## while the splitter / power commands do not exist (L1/L2/L3 not merged yet).

const BotReport := preload("res://tools/bot_report.gd")


func test_power_profile_runs_clean() -> void:
	var bus := make_bus()
	var r := BotReport.play(1, 6, bus, "power")
	assert_true(str(r["cause"]) != "", "bot finished")
	var probe := make_sim(1)
	if not probe.has_method("place_belt_node"):
		assert_eq(int(r.get("l2_nodes", 0)), 0, "no splitter command yet -> no nodes")
	else:
		assert_true(int(r.get("l2_nodes", 0)) % 2 == 0)


func test_power_profile_is_deterministic() -> void:
	var a := BotReport.play(2, 5, make_bus(), "power")
	var b := BotReport.play(2, 5, make_bus(), "power")
	assert_eq(a["refined"], b["refined"])
	assert_eq(a["final_contam"], b["final_contam"])
	assert_eq(a["waves"], b["waves"])
