extends TestCase
## EN1 C1: dirty fuel cell recipe pollutes and needs bulk_refining.


func test_recipe_def() -> void:
	var r: Dictionary = Defs.get_default().recipes["fuel_cell_dirty"]
	assert_true(bool(r["pollutes"]))
	assert_eq(int(r["outputs"]["fuel_cell"]), 1)
	assert_eq(int(r["outputs"]["waste"]), 3)
	assert_true(Defs.get_default().research["bulk_refining"]["unlocks"]["recipes"].has("fuel_cell_dirty"))


func test_contaminates_on_batch() -> void:
	var sim := make_sim(3, false, 24, 24, peaceful_defs())
	var lvl := sim.contamination.level
	sim.bus.batch_refined.emit(0, "fuel_cell_dirty")
	assert_gt(sim.contamination.level, lvl)


func test_smelter_runs_it_only_after_tech() -> void:
	var sim := make_sim(3, false, 24, 24, peaceful_defs())
	var b := sim.buildings.place("smelter", Vector2i(10, 10), false)
	assert_true(sim.endings.tech_ok("refine_essence"))
	assert_false(sim.endings.tech_ok("fuel_cell_dirty"))
	# EN1 puts tech-gated recipes in gated_recipes, not station_recipes
	assert_true(b.gated_recipes.has("fuel_cell_dirty"))
	sim.research.done.append("bulk_refining")
	assert_true(sim.endings.tech_ok("fuel_cell_dirty"))
