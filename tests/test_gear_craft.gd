extends TestCase
## F3b: craft_gear_* recipes are research-gated, cost plates + refined essence (the quota currencies) and produce a GearItem.

const RECIPES := {
	"craft_gear_vest": "kevlar_vest", "craft_gear_helmet": "helmet", "craft_gear_gloves": "work_gloves",
	"craft_gear_greaves": "greaves", "craft_gear_rifle": "rifle",
}


func _locked_sim(seed_v := 3) -> Simulation:
	var sim := make_sim(seed_v, false, 40, 40, peaceful_defs())
	sim.research.gating = true
	return sim


func test_every_recipe_has_a_gating_tech() -> void:
	var d := Defs.get_default()
	for rid: String in RECIPES:
		var owners := 0
		for t: String in d.research:
			if rid in d.research[t].get("unlocks", {}).get("recipes", []):
				owners += 1
				assert_gt(int(d.research[t]["tier"]), 1, rid + " is behind a paid tier-2+ tech")
		assert_eq(owners, 1, rid + " has exactly one gating tech")
		assert_eq(str(d.recipes[rid]["gear_craft"]), RECIPES[rid])
		assert_true(d.gear.has(RECIPES[rid]), "gear base exists")


func test_locked_until_researched() -> void:
	var sim := _locked_sim()
	var b := sim.buildings.place("workbench", Vector2i(10, 5), false)
	for rid: String in RECIPES:
		assert_false(sim.research.recipe_unlocked(rid), rid + " locked at start")
		assert_eq(sim.add_bill(b.id, rid, "count", 1), -1, rid + " bill refused while locked")
	sim.research.done.append("assembly")
	sim.research.done.append("advanced_recipes")
	for rid: String in RECIPES:
		assert_true(sim.research.recipe_unlocked(rid))
		assert_gt(sim.add_bill(b.id, rid, "count", 1), 0, rid + " bill accepted once researched")


func test_costs_are_plates_and_refined_and_scale_with_slot_value() -> void:
	var d := Defs.get_default()
	var last_ref := 0
	for rid: String in ["craft_gear_gloves", "craft_gear_helmet", "craft_gear_greaves", "craft_gear_vest", "craft_gear_rifle"]:
		var inp: Dictionary = d.recipes[rid]["inputs"]
		assert_eq(inp.keys().size(), 2, rid + " costs exactly plates + refined essence")
		assert_gt(int(inp["plate"]), 0)
		assert_gt(int(inp["refined_essence"]), last_ref - 1, rid + " not cheaper than the previous tier")
		last_ref = int(inp["refined_essence"])
	# one vest = two installments of refined essence, a small slice of the 60-plate petition I
	var vest: Dictionary = d.recipes["craft_gear_vest"]["inputs"]
	assert_eq(int(vest["refined_essence"]), 2 * int(d.debt["installment"]))
	assert_lt(int(vest["plate"]) * 10, 60)


func test_crafting_consumes_inputs_and_produces_gear() -> void:
	for rid: String in RECIPES:
		var sim := make_sim(7, false, 40, 40, peaceful_defs())
		var c := sim.colonists.spawn(Vector2i(5, 5))
		var b := sim.buildings.place("workbench", Vector2i(10, 5), false)
		var inp: Dictionary = sim.defs.recipes[rid]["inputs"]
		for item: String in inp:
			sim.ledger.record_produced(item, int(inp[item]), "test")
			b.input[item] = int(inp[item])
		assert_gt(sim.add_bill(b.id, rid, "count", 1), 0)
		sim.crafting._select(b)
		assert_true(sim.buildings.work(b, int(b.recipe["work_ticks"]), c), rid)
		assert_eq(sim.equipment.instances.size(), 1, rid + " produced one gear instance")
		var g: GearItem = sim.equipment.instances.values()[0]
		assert_eq(g.base, RECIPES[rid])
		assert_eq(g.owner, c.id)
		for item: String in inp:
			assert_eq(int(b.input.get(item, 0)), 0, "%s consumed %s" % [rid, item])
