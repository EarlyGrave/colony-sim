extends TestCase
## E5: waste -> contamination -> forecast of the planet's end.

var cfg: Dictionary = Defs.get_default().balance["contamination"]


func test_forecast_formula() -> void:
	var f := ForecastModel.estimate(20.0, 4.0, cfg)
	var max_level := float(cfg["max"])
	assert_near(f["days"], (max_level - 20.0) / 4.0, 0.001)
	var rel := float(cfg["base_error"]) + float(cfg["error_growth"]) * 20.0 / max_level
	assert_near(f["error"], f["days"] * rel, 0.001)


func test_forecast_shrinks_with_rate_and_level() -> void:
	var slow := ForecastModel.estimate(10.0, 1.0, cfg)
	var fast := ForecastModel.estimate(10.0, 5.0, cfg)
	var later := ForecastModel.estimate(60.0, 1.0, cfg)
	assert_lt(fast["days"], slow["days"], "faster contamination must shorten forecast")
	assert_lt(later["days"], slow["days"])
	# Relative uncertainty grows with contamination.
	assert_gt(later["error"] / later["days"], slow["error"] / slow["days"])


func test_forecast_never_divides_by_zero() -> void:
	var f := ForecastModel.estimate(0.0, 0.0, cfg)
	assert_near(f["days"], float(cfg["max"]) / float(cfg["min_rate_per_day"]), 0.001)
	assert_near(ForecastModel.estimate(150.0, 3.0, cfg)["days"], 0.0, 0.0001)


func _refining_sim(seed_value: int, ore: int) -> Simulation:
	var sim := make_sim(seed_value, false, 20, 20, peaceful_defs())
	sim.colonists.spawn(Vector2i(2, 2))
	sim.colonists.spawn(Vector2i(3, 2))
	for y in 2:
		for x in 3:
			sim.set_zone(Vector2i(2 + x, 10 + y), "stockpile")
	for y in 3:
		for x in 3:
			sim.set_zone(Vector2i(14 + x, 10 + y), "waste_dump")
	sim.ledger.record_produced("essence_ore", ore, "test")
	sim.items.drop(Vector2i(2, 10), "essence_ore", ore)
	sim.buildings.place("refinery", Vector2i(9, 5), false)
	return sim


func test_forecast_revealed_by_first_refine() -> void:
	var sim := _refining_sim(1, 10)
	var revealed := [false]
	sim.bus.forecast_revealed.connect(func() -> void: revealed[0] = true)
	assert_false(sim.contamination.revealed)
	sim.run_ticks(600)
	assert_true(sim.contamination.revealed)
	assert_true(revealed[0])


func test_more_refining_means_worse_forecast() -> void:
	var little := _refining_sim(2, 10)   # one batch only
	var lots := _refining_sim(2, 100)   # keeps refining
	little.run_ticks(2400)
	lots.run_ticks(2400)
	assert_gt(lots.buildings.refined_batches, little.buildings.refined_batches)
	assert_gt(lots.contamination.level, little.contamination.level)
	assert_lt(lots.contamination.forecast()["days"], little.contamination.forecast()["days"])


func test_waste_in_dump_contaminates_less() -> void:
	var a := make_sim(3, false, 10, 10)
	var b := make_sim(3, false, 10, 10)
	b.set_zone(Vector2i(5, 5), "waste_dump")
	a.items.add_at(Vector2i(5, 5), "waste", 40)
	b.items.add_at(Vector2i(5, 5), "waste", 40)
	a.run_ticks(1200)
	b.run_ticks(1200)
	assert_gt(a.contamination.level, 0.0)
	assert_lt(b.contamination.level, a.contamination.level)


func test_planet_death_ends_game() -> void:
	var sim := make_sim(4, false, 10, 10)
	var reason := [""]
	sim.bus.game_over.connect(func(r: String) -> void: reason[0] = r)
	sim.contamination.level = float(cfg["max"]) - 0.001
	sim.items.add_at(Vector2i(1, 1), "waste", 50)
	sim.run_ticks(50)
	assert_eq(reason[0], "planet_dead")
	var t := sim.tick
	sim.run_ticks(10)
	assert_eq(sim.tick, t, "simulation must stop after game over")
