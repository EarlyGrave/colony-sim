extends TestCase
## Drafting and colonist combat vs creatures.


func _scene(seed_value := 3) -> Simulation:
	return make_sim(seed_value, false, 30, 30, peaceful_defs())


func _crawler(sim: Simulation, cell: Vector2i) -> Enemy:
	return sim.threats._spawn("crawler", cell)


func test_drafted_rifle_kills_crawler() -> void:
	var sim := _scene()
	var c := sim.colonists.spawn(Vector2i(5, 5))
	c.combat.weapon = "rifle"
	assert_true(sim.set_drafted(c.id, true))
	_crawler(sim, Vector2i(11, 5))
	sim.run_ticks(400)
	assert_eq(sim.threats.kills, 1, "crawler should die to the rifle")
	assert_eq(c.cell, Vector2i(5, 5), "drafted colonist holds position")


func test_melee_kills_adjacent_crawler() -> void:
	var sim := _scene()
	var c := sim.colonists.spawn(Vector2i(5, 5))
	sim.set_drafted(c.id, true)
	_crawler(sim, Vector2i(6, 5))
	sim.run_ticks(400)
	assert_eq(sim.threats.kills, 1, "shiv should kill an adjacent crawler")
	assert_true(c.alive)


func _hits(sim: Simulation, level: int, shots: int) -> int:
	var c := sim.colonists.spawn(Vector2i(5, 5))
	c.combat.weapon = "rifle"
	c.skills.levels["shooting"] = level
	sim.ammo._pouch_init(c)
	c.combat.pouch = 100000  # this test is about hit chance, not logistics
	var e := _crawler(sim, Vector2i(10, 5))
	e.hp = 1.0e9
	var dmg := float(sim.defs.weapons["weapons"]["rifle"]["damage"])
	var before := e.hp
	for i in shots:
		c.combat.next_attack_tick = 0
		sim.combat.try_attack(c, e)
	return roundi((before - e.hp) / dmg)


func test_shooting_skill_changes_hit_rate() -> void:
	var low := _hits(_scene(11), 0, 400)
	var high := _hits(_scene(11), 12, 400)
	assert_gt(high, low + 40, "skill 12 should hit clearly more often than skill 0 (%d vs %d)" % [high, low])


func test_drafted_does_not_take_work() -> void:
	var sim := _scene()
	sim.map.set_tile(Vector2i(10, 10), MapGrid.Tile.DEPOSIT, 100)
	sim.designate_mine(Vector2i(10, 10), true)
	var c := sim.colonists.spawn(Vector2i(2, 2))
	sim.set_drafted(c.id, true)
	sim.run_ticks(800)
	assert_eq(sim.ledger.get_count("mining:essence_ore"), 0, "drafted colonist mined")
	assert_eq(c.job.type, "draft")
	sim.set_drafted(c.id, false)
	sim.run_ticks(1500)
	assert_gt(sim.ledger.get_count("mining:essence_ore"), 0, "undrafted colonist should work again")


func test_drafted_ignores_alarm() -> void:
	var sim := _scene()
	var c := sim.colonists.spawn(Vector2i(2, 2))
	sim.buildings.place("hq", Vector2i(10, 10), false)
	sim.set_drafted(c.id, true)
	sim.set_alarm(true)
	sim.run_ticks(100)
	assert_false(c.hidden)
	assert_eq(c.cell, Vector2i(2, 2))


func test_order_move_and_attack() -> void:
	var sim := _scene()
	var c := sim.colonists.spawn(Vector2i(2, 2))
	assert_false(sim.order_move(c.id, Vector2i(8, 8)), "needs draft")
	sim.set_drafted(c.id, true)
	assert_true(sim.order_move(c.id, Vector2i(8, 8)))
	sim.run_ticks(100)
	assert_eq(c.cell, Vector2i(8, 8))
	var e := _crawler(sim, Vector2i(14, 8))
	assert_true(sim.order_attack(c.id, e.id))
	sim.run_ticks(500)
	assert_eq(sim.threats.kills, 1, "ordered attack should walk up and kill")


func test_undrafted_fights_back_without_alarm() -> void:
	var sim := _scene()
	var c := sim.colonists.spawn(Vector2i(5, 5))
	assert_false(sim.alarm)
	_crawler(sim, Vector2i(6, 5))
	sim.run_ticks(400)
	assert_eq(sim.threats.kills, 1, "bitten colonist should hit back")


func test_hurt_colonist_retreats_to_shelter() -> void:
	var sim := _scene()
	sim.buildings.place("hq", Vector2i(10, 5), false)
	var c := sim.colonists.spawn(Vector2i(8, 5))
	sim.health.apply_damage(c, 70.0, "torso", "bruise")
	assert_true(sim.combat.is_low_hp(c))
	var e := _crawler(sim, Vector2i(9, 5))
	e.hp = 1.0e9
	sim.run_ticks(60)
	assert_true(c.hidden, "low-hp colonist should hide in the shelter")


func _run_fight(seed_value: int) -> Array:
	var sim := _scene(seed_value)
	var c := sim.colonists.spawn(Vector2i(5, 5))
	c.combat.weapon = "rifle"
	sim.set_drafted(c.id, true)
	for x in [10, 12, 14]:
		_crawler(sim, Vector2i(x, 6))
	sim.run_ticks(500)
	return [sim.threats.kills, c.hp, c.skills.xp["shooting"], sim.rng.randi()]


func test_deterministic() -> void:
	assert_eq(_run_fight(21), _run_fight(21))


func test_start_colony_gives_engineer_a_rifle() -> void:
	var sim := make_sim(4, true, 24, 24, peaceful_defs())
	for c in sim.colonists.list:
		assert_eq(c.combat.weapon, "rifle" if c.engineer else "prison_shiv")
