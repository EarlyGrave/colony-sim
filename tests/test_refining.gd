extends TestCase
## E4: refinery runs its recipe from data; first batch fires first_refine_done.


## Small sandbox: one colonist, refinery, stockpile with ore, waste dump.
func _setup(defs: Defs = null, ore := 40) -> Simulation:
	if defs == null:
		defs = peaceful_defs()
	defs.balance["threat"]["enabled"] = false
	var sim := make_sim(7, false, 20, 20, defs)
	sim.colonists.spawn(Vector2i(2, 2))
	for y in 2:
		for x in 3:
			sim.set_zone(Vector2i(2 + x, 10 + y), "stockpile")
			sim.set_zone(Vector2i(14 + x, 10 + y), "waste_dump")
	sim.ledger.record_produced("essence_ore", ore, "test")
	sim.items.drop(Vector2i(2, 10), "essence_ore", ore)
	var b := sim.buildings.place("refinery", Vector2i(9, 5), false)
	assert_true(b != null, "refinery not placed")
	return sim


func test_refinery_produces_per_recipe_and_fires_event_once() -> void:
	var sim := _setup()
	var fired := [0]
	sim.bus.first_refine_done.connect(func() -> void: fired[0] += 1)
	sim.run_ticks(1500)
	var r: Dictionary = sim.defs.recipes["refine_essence"]
	var batches := sim.buildings.refined_batches
	assert_gt(batches, 1, "expected several batches")
	assert_eq(fired[0], 1, "first_refine_done must fire exactly once")
	assert_eq(sim.ledger.get_count("recipe:refined_essence"), batches * int(r["outputs"]["refined_essence"]))
	assert_eq(sim.ledger.get_count("recipe:waste"), batches * int(r["outputs"]["waste"]))
	assert_eq(sim.ledger.get_count("recipe:essence_ore"), batches * int(r["inputs"]["essence_ore"]))
	# Products get hauled to their zones.
	assert_gt(sim.items.count_stored("refined_essence"), 0, "refined essence not stored")
	assert_gt(sim.items.count_stored("waste"), 0, "waste not dumped")


func test_recipe_is_data_driven() -> void:
	var defs := Defs.get_default().duplicate_defs()
	defs.recipes["refine_essence"]["inputs"] = {"essence_ore": 4}
	defs.recipes["refine_essence"]["outputs"] = {"refined_essence": 2, "waste": 1}
	defs.recipes["refine_essence"]["work_ticks"] = 20
	var sim := _setup(defs, 8)
	sim.run_ticks(800)
	assert_eq(sim.buildings.refined_batches, 2)
	assert_eq(sim.items.count_world("refined_essence"), 4)
	assert_eq(sim.items.count_world("waste"), 2)
	assert_eq(sim.items.count_world("essence_ore"), 0)


func test_no_refining_without_operator() -> void:
	var sim := make_sim(8, false, 12, 12)
	var b := sim.buildings.place("refinery", Vector2i(4, 4), false)
	b.add_input("essence_ore", 20)
	sim.run_ticks(500)
	assert_eq(sim.buildings.refined_batches, 0)


func test_full_output_blocks_refinery() -> void:
	# Without a waste dump the waste piles up in the output buffer and the
	# chain stalls: one broken link, not a crash.
	var sim := make_sim(9, false, 20, 20, peaceful_defs())
	sim.colonists.spawn(Vector2i(2, 2))
	var b := sim.buildings.place("refinery", Vector2i(9, 5), false)
	sim.ledger.record_produced("essence_ore", 200, "test")
	for i in 4:
		sim.set_zone(Vector2i(2 + i, 12), "stockpile")
	sim.items.drop(Vector2i(2, 12), "essence_ore", 200)
	sim.run_ticks(4000)
	var cap := int(b.def["output_capacity"])
	assert_true(b.output_total() <= cap)
	assert_false(b.can_run_recipe(), "refinery should be blocked by waste")
	assert_eq(sim.items.count_world("essence_ore"), sim.ledger.balance_of("essence_ore"))
	assert_eq(sim.items.count_world("waste"), sim.ledger.balance_of("waste"))


func test_building_cost_is_paid_from_storage() -> void:
	var sim := make_sim(10)
	var before := sim.items.count_stored("essence_ore")
	var cell := sim.map_center() + Vector2i(-5, 3)
	var err := sim.can_place_building("refinery", cell)
	assert_eq(err, "")
	assert_true(sim.place_instant("refinery", cell) != null)
	assert_eq(sim.items.count_stored("essence_ore"), before - 20)
	assert_eq(sim.items.count_world("essence_ore"), sim.ledger.balance_of("essence_ore"))
	# Not enough ore for a second one beyond what's left.
	assert_ne(sim.can_place_building("refinery", cell), "", "occupied cell must be rejected")
