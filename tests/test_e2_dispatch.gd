extends TestCase
const Scenario := preload("res://tests/scenario.gd")
## E2 Sector Dispatch: bundle -> permanent modifier, gated by e2_enabled.


func _defs(on: bool) -> Defs:
	var d := peaceful_defs()
	d.balance["e2_enabled"] = on
	return d


func _stock(sim: Simulation, food: int, ess: int = 0, ore: int = 0) -> void:
	var base := sim.map_center() + Vector2i(-8, 4)
	for k in 24:
		sim.set_zone(base + Vector2i(k % 4, k / 4), "stockpile")
	sim.ledger.record_produced("raw_food", food, "test")
	sim.ledger.record_produced("refined_essence", ess, "test")
	sim.ledger.record_produced("essence_ore", ore, "test")
	var cell := 0
	for pair: Array in [["raw_food", food], ["refined_essence", ess], ["essence_ore", ore]]:
		var left: int = pair[1]
		while left > 0:
			var n := mini(left, 50)
			sim.items.drop(base + Vector2i(cell % 4, cell / 4), str(pair[0]), n)
			cell += 1
			left -= n


func test_gated_off() -> void:
	var sim := make_sim(1, true, 48, 48, _defs(false))
	_stock(sim, 150)
	assert_false(sim.dispatch_sector(1, "calm"))
	assert_eq(sim.contracts.wave_mult(), 1.0)


func test_tier_order_and_wave_mult() -> void:
	var sim := make_sim(1, true, 48, 48, _defs(true))
	assert_false(sim.dispatch_sector(1, "calm"), "no stock")
	_stock(sim, 500, 40, 80)
	assert_false(sim.dispatch_sector(2, "calm"), "tier 2 before 1")
	assert_true(sim.dispatch_sector(1, "calm"))
	assert_near(sim.contracts.wave_mult(), 0.9, 0.0001)
	assert_false(sim.dispatch_sector(2, "calm"), "modifier used once")
	assert_true(sim.dispatch_sector(2, "recruit"))
	assert_near(sim.contracts.take_raid_mult(), 0.9, 0.0001)
	assert_true(sim.dispatch_sector(3, "smelting"))
	assert_true(sim.research.done.has("smelting"))
	assert_false(sim.dispatch_sector(4, "calm"))


func test_recruit_adds_colonist() -> void:
	var sim := make_sim(2, true, 48, 48, _defs(true))
	_stock(sim, 250)
	var n := sim.colonists.alive_count()
	assert_true(sim.dispatch_sector(1, "recruit"))
	assert_eq(sim.colonists.alive_count(), n + 1)
	assert_true(sim.get_sector_state()["tiers"][0]["done"])


func test_deterministic() -> void:
	var out: Array = []
	for _k in 2:
		var sim := make_sim(5, true, 48, 48, _defs(true))
		_stock(sim, 250)
		sim.dispatch_sector(1, "recruit")
		for i in 200:
			sim.step()
		out.append([sim.colonists.alive_count(), sim.items.count_stored("raw_food")])
	assert_eq(out[0], out[1])
