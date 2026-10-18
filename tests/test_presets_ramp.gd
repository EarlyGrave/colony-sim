extends TestCase
## B1: presets form a monotone difficulty ramp (numbers read from data/presets.json) and
## conveyance is a paid start tech (belts need research, so the hand phase lasts).


func _p() -> Dictionary:
	return Defs.get_default().presets["presets"]


func test_ramp_is_monotone() -> void:
	var p := _p()
	for k in ["wave_strength_mult", "waste_mult", "starting_debt_mult"]:
		assert_true(float(p["short_stay"][k]) < float(p["standard_term"][k]), k + " short < standard")
		assert_true(float(p["standard_term"][k]) < float(p["hard_time"][k]), k + " standard < hard")


func test_ramp_values() -> void:
	var p := _p()
	assert_near(float(p["short_stay"]["waste_mult"]), 0.45, 0.001)
	assert_near(float(p["short_stay"]["wave_strength_mult"]), 0.6, 0.001)
	assert_near(float(p["hard_time"]["waste_mult"]), 1.15, 0.001)
	assert_near(float(p["hard_time"]["wave_strength_mult"]), 1.15, 0.001)


func test_conveyance_is_paid_start() -> void:
	var sim := make_sim(1)
	assert_false(sim.research.is_done("conveyance"), "belts need research")
	assert_true(sim.research.is_done("drilling"))
	assert_gt(float(sim.defs.research["conveyance"]["cost"]["essence"]), 0.0)
	assert_true(int(sim.defs.research["hand_tools"]["cost"]["bench_ticks"]) >= 1800, "T0 bench_ticks x3")
