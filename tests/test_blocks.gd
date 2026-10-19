extends TestCase
## Cell Block Standing (I1): assignment, Informant, Standing bounds, despair multiplier, determinism,
## save/load round-trip.


func _sim(seed_value := 5) -> Simulation:
	var d := peaceful_defs()
	d.debt["grace_days"] = 0
	var sim := make_sim(seed_value, true, 24, 24, d)
	var f := sim.map_center() + Vector2i(3, 3)
	sim.set_zone(f, "stockpile")
	sim.ledger.record_produced("raw_food", 400, "test")
	sim.items.drop(f, "raw_food", 400)
	sim.run_ticks(1)
	return sim


func _add_inmates(sim: Simulation, n: int) -> void:
	for i in n:
		var c := ColonistGenerator.generate(sim, sim.map_center() + Vector2i(i, -2))
		sim.colonists.add(c)


func test_every_colonist_has_a_block() -> void:
	var sim := _sim()
	for c in sim.colonists.list:
		assert_true(sim.blocks.standing.has(sim.blocks.block_of(c)), "colonist %d has a known block" % c.id)


func test_informant_exactly_one_at_six_inmates() -> void:
	var sim := _sim()
	_add_inmates(sim, 8)
	sim.run_ticks(sim.ticks_per_day * 2)
	var n := 0
	for c in sim.colonists.list:
		if sim.blocks.block_of(c) == "informant":
			n += 1
	assert_eq(n, 1)
	assert_gt(sim.blocks.informant_id(), 0)
	sim.run_ticks(sim.ticks_per_day * 2)
	n = 0
	for c in sim.colonists.list:
		if sim.blocks.block_of(c) == "informant":
			n += 1
	assert_eq(n, 1, "still one after more days")


func test_standing_moves_and_stays_bounded() -> void:
	var sim := _sim()
	var c: Colonist = sim.colonists.list[0]
	var b := sim.blocks.block_of(c)
	var before := sim.blocks.standing_of(b)
	sim.blocks.on_installment_paid(c)
	assert_gt(sim.blocks.standing_of(b), before)
	for i in 40:
		sim.blocks.on_installment_missed(c)
		sim.blocks._on_died(c.id)
	assert_eq(sim.blocks.standing_of(b), 0.0)
	for i in 60:
		sim.blocks.on_installment_paid(c)
	assert_eq(sim.blocks.standing_of(b), 100.0)
	for k: String in sim.blocks.standing:
		assert_true(sim.blocks.standing[k] >= 0.0 and sim.blocks.standing[k] <= 100.0)


func test_low_standing_raises_despair_mult() -> void:
	var sim := _sim()
	var c: Colonist = sim.colonists.list[0]
	var b := sim.blocks.block_of(c)
	assert_near(sim.blocks.despair_mult(c), 1.0, 0.0001)
	sim.blocks.standing[b] = 0.0
	assert_gt(sim.blocks.despair_mult(c), 1.0)
	sim.blocks.standing[b] = 100.0
	assert_lt(sim.blocks.despair_mult(c), 1.0)


func test_disabled_is_neutral() -> void:
	var sim := _sim()
	sim.blocks.cfg["enabled"] = false
	var c: Colonist = sim.colonists.list[0]
	sim.blocks.standing[sim.blocks.block_of(c)] = 0.0
	assert_eq(sim.blocks.despair_mult(c), 1.0)


func _run_hash(seed_value: int) -> int:
	var sim := _sim(seed_value)
	_add_inmates(sim, 6)
	sim.run_ticks(sim.ticks_per_day * 12)
	return SaveGame.state_hash(sim)


func test_deterministic_hash() -> void:
	assert_eq(_run_hash(7), _run_hash(7))


func test_save_load_keeps_standing() -> void:
	var d0 := peaceful_defs()
	d0.debt["grace_days"] = 0
	var sim := make_sim(5, true, 24, 24, d0)  # command-log replay: no out-of-band item drops
	sim.run_ticks(sim.ticks_per_day * 14)  # unpaid installments move Standing
	sim.run_ticks(5)
	var text := SaveGame.to_json(sim)
	var d := peaceful_defs()
	d.debt["grace_days"] = 0
	var res := SaveGame.load_json(text, make_bus(), d)
	assert_true(res["ok"])
	var sim2: Simulation = res["sim"]
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))
	for k: String in sim.blocks.standing:
		assert_near(sim2.blocks.standing[k], sim.blocks.standing[k], 0.0001)
	assert_eq(sim2.blocks.informant_id(), sim.blocks.informant_id())
