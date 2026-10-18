extends TestCase
## T3: belt hp / stall, creature bites, repair job, turret_target_mode.


func _scene(plates := 5) -> Simulation:
	var sim := make_sim(3, false, 40, 40, peaceful_defs())
	for x in range(5, 20):
		sim.logistics.place_belt_cell(Vector2i(x, 10), 1)
	sim.set_zone(Vector2i(3, 3), "stockpile")
	if plates > 0:
		sim.ledger.record_produced("plate", plates, "test")
		sim.items.drop(Vector2i(3, 3), "plate", plates)
	return sim


func test_damaged_belt_stalls_then_repair_resumes() -> void:
	var sim := _scene()
	var g := sim.logistics.belts
	var c := Vector2i(10, 10)
	assert_eq(g.hp_at(c), 40.0)
	var h0 := g.state_hash()
	sim.logistics.damage_belt(c, 5.0)
	assert_ne(g.state_hash(), h0, "hp is in the hash")
	g.insert(Vector2i(5, 10), 1)
	sim.logistics.damage_belt(c, 24.0)  # 11 < 12 = 30% of 40
	assert_true(g.is_stalled(c))
	for t in 100:
		g.step()
	assert_eq(g.item_at(Vector2i(10, 10)), 1, "item stuck on the stalled tile")
	sim.colonists.spawn(Vector2i(4, 4))
	var plates0 := sim.items.count_stored("plate")
	sim.run_ticks(400)
	assert_eq(g.hp_at(c), 40.0, "repaired")
	assert_eq(sim.items.count_stored("plate"), plates0 - 1, "exact cost")
	assert_eq(sim.jobs.reserved.size(), 0, "no stuck reservation")
	assert_true(g.item_count == 1 or g.extracted > 0)


func test_no_plates_no_repair_job() -> void:
	var sim := _scene(0)
	sim.logistics.damage_belt(Vector2i(10, 10), 30.0)
	sim.colonists.spawn(Vector2i(4, 4))
	sim.run_ticks(200)
	assert_true(sim.logistics.belts.is_damaged(Vector2i(10, 10)))
	assert_eq(sim.jobs.reserved.size(), 0)


func test_crawler_bites_belt_and_hash_deterministic() -> void:
	var hs: Array = []
	for k in 2:
		var sim := _scene()
		sim.threats._spawn("crawler", Vector2i(10, 11))
		sim.run_ticks(300)
		assert_true(sim.logistics.belts.hp_damaged.size() > 0, "bitten")
		hs.append(sim.logistics.state_hash())
	assert_eq(hs[0], hs[1])


func test_machine_breaks_below_threshold() -> void:
	var sim := _scene(0)
	var b := sim.buildings.place("refinery", Vector2i(20, 20), false)
	assert_true(b != null)
	sim.buildings.damage(b, b.max_hp * 0.8)
	assert_true(b.broken)
	assert_true(b.needs_repair(sim))


func test_turret_mode_weakest() -> void:
	var sim := _scene(0)
	sim.set_rule("turret_target_mode", "weakest")
	assert_eq(sim.get_rule_mode("turret_target_mode"), "weakest")
	sim.set_rule("turret_target_mode", "bogus")
	assert_eq(sim.get_rule_mode("turret_target_mode"), "weakest")
	var t := sim.buildings.place("turret", Vector2i(20, 20), false)
	assert_true(t != null)
	var near := sim.threats._spawn("brute", Vector2i(22, 20))
	var weak := sim.threats._spawn("crawler", Vector2i(26, 20))
	weak.hp = 1.0
	sim.threats._tick_turrets()
	assert_true(weak.hp <= 0.0 or not sim.threats.enemies.has(weak), "weakest shot first")
	assert_eq(near.hp, near.max_hp)
