extends TestCase
## F2a: shipped metro config is live and sane (the track itself is covered by test_metro_track).


func test_shipped_config_enabled() -> void:
	var cfg: Dictionary = Defs.get_default().balance["metro"]
	assert_true(bool(cfg["enabled"]), "metro.enabled ships true")
	assert_true(float(cfg["first_raid_day"]) >= 5.0, "no drone raid in the opening days")
	assert_true(float(cfg["min_defiance"]) > 0.0, "a compliant colony is never raided")


func test_raid_rows_registered_and_tagged() -> void:
	var sim := make_sim(7, false, 40, 40)
	for id: String in ["drone_sweep", "collector_drop", "collector_assault"]:
		assert_true(sim.defs.raids.has(id), id)
		assert_eq(sim.defs.raids[id]["faction"], "metropolis")


func test_fresh_colony_has_no_defiance() -> void:
	var sim := make_sim(7, false, 40, 40)
	var m := sim.threats.metro()
	assert_eq(m.defiance, 0.0)
	assert_eq(m.raids_started, 0)
	assert_false(m.fight_path())
