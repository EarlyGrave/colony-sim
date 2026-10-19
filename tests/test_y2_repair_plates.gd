extends TestCase
## Y2: early plate economy - hand_plate is cheap and available at the first workbench, repairs cost <= 1 plate.


func test_hand_plate_cheap_and_repair_cost_low() -> void:
	var sim: Simulation = make_sim(1)
	var r: Dictionary = sim.defs.recipes["hand_plate"]
	assert_true(int(r["inputs"]["essence_ore"]) <= 3, "hand_plate costs <= 3 essence ore")
	assert_true("workbench" in r["benches"], "hand_plate is a workbench bill")
	assert_true(not r.has("research"), "no research gate")
	var cost: Dictionary = sim.defs.balance["line_damage"]["machine_repair_cost"]
	assert_eq(int(cost["plate"]), 1, "machine repair costs 1 plate")
