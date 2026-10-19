extends TestCase
## YX: the taint cap stops waste-making recipes (refining, smelting) but not plate hammering / assembling.


func test_cap_blocks_refining_not_bench_or_assembler_recipes() -> void:
	var sim := make_sim(1, false, 24, 24, peaceful_defs())
	sim.research.done.append("filters")
	sim.defs.rules["refine_cap"]["max_contamination_percent"] = 10
	sim.set_rule("refine_cap", true)
	sim.contamination.level = 50.0
	assert_true(sim.buildings.refining_capped())
	var r := sim.buildings.place("refinery", Vector2i(4, 4), false)
	r.add_input("essence_ore", 10)
	r.recipe = r.station_defs["refine_essence"] if not r.station_defs.is_empty() else sim.defs.recipes["refine_essence"]
	assert_false(sim.buildings.may_operate(r), "refining stops at the cap")
	var a := sim.buildings.place("assembler", Vector2i(10, 10), false)
	a.add_input("ingot_iron", 2)
	a.recipe = sim.defs.recipes["make_plate"]
	a.recipe_id = "make_plate"
	assert_true(sim.buildings.may_operate(a), "plate making ignores the cap")
