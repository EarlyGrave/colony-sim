extends TestCase
## DB: output of a miner on a blocked (deposit) cell is haulable; blueprints may use loose ore.

const Scenario := preload("res://tests/scenario.gd")


func test_blocked_building_output_is_hauled() -> void:
	var sim := make_sim(3, true, 64, 64, peaceful_defs())
	var r := Scenario.build_chain(sim, false, true)
	assert_false(r.is_empty())
	var miner: Building = r["miner"]
	for i in 6:
		sim.set_zone(miner.cell + Vector2i(i, 5), "stockpile")
	sim.pathfinder.set_blocked(miner.cell, true)
	assert_false(sim.pathfinder.is_walkable(miner.cell))
	miner.output["essence_ore"] = 3
	var c: Colonist = sim.colonists.list[0]
	c.cell = miner.cell + Vector2i(0, 3)  # nearest work is the miner output
	var j := HaulGiver.new(sim).find(c)
	assert_true(j != null)
	if j != null:
		assert_eq((j as HaulJob).src_building, miner.id)


func test_blueprint_takes_loose_ore() -> void:
	var sim := make_sim(3, true, 64, 64, peaceful_defs())
	var c: Colonist = sim.colonists.list[0]
	var spot := Scenario.find_spot(sim, "miner", sim.map_center(), 3)
	assert_true(spot.x >= 0)
	assert_true(sim.place_building("miner", spot) != null)
	sim.items.consume_stored("essence_ore", sim.items.count_stored("essence_ore"), c.cell)
	assert_eq(sim.items.count_stored("essence_ore"), 0)
	sim.items.drop(c.cell + Vector2i(1, 0), "essence_ore", 15)
	assert_true(DeliverMaterialsGiver.new(sim).find(c) != null)
