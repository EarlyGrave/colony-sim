extends TestCase
## F2c: creature gear drops (enemies.json `loot`), pollution-scaled rarity, rng isolation.


func _scene(seed_v: int) -> Simulation:
	var sim := make_sim(seed_v, false, 40, 40, peaceful_defs())
	sim.colonists.spawn(Vector2i(5, 5))
	_bare(sim)
	sim.tick = 7 * sim.ticks_per_day
	return sim


func test_ilvl_by_day() -> void:
	var sim := _scene(1)
	assert_eq(sim.threats.loot_ilvl(0), 0)
	assert_eq(sim.threats.loot_ilvl(20), 3)
	assert_eq(sim.threats.loot_ilvl(50), 10)


func test_loot_blocks_present() -> void:
	var sim := _scene(1)
	for k in ["crawler", "brute", "spitter", "burrower", "mimic"]:
		assert_true(sim.defs.enemies[k].has("loot"), k + " has loot")
		for b: String in sim.defs.enemies[k]["loot"]["bases"]:
			assert_true(sim.defs.gear.has(b), "known base " + b)


func test_drop_gives_owned_gear_and_keeps_sim_rng() -> void:
	var sim := _scene(5)
	sim.defs.enemies["brute"]["loot"]["chance"] = 1.0
	var before := sim.rng.state
	var e := sim.threats._spawn("brute", Vector2i(8, 8))
	assert_true(e != null, "spawned")
	sim.threats.damage_enemy(e, 9999.0, "generic", sim.colonists.list[0])
	assert_eq(sim.equipment.instances.size(), 1, "one drop")
	assert_eq(sim.rng.state, before, "sim.rng untouched by the loot roll")
	var g: GearItem = sim.equipment.instances.values()[0]
	assert_eq(g.owner, sim.colonists.list[0].id)


func test_no_loot_block_no_drop() -> void:
	var sim := _scene(5)
	sim.defs.enemies["crawler"].erase("loot")
	var e := sim.threats._spawn("crawler", Vector2i(8, 8))
	sim.threats.damage_enemy(e, 9999.0, "generic", sim.colonists.list[0])
	assert_eq(sim.equipment.instances.size(), 0)


func _rare_share(frac_level: float) -> int:
	var sim := _scene(9)
	sim.defs.enemies["mimic"]["loot"]["chance"] = 1.0
	sim.contamination.level = frac_level * float(sim.defs.balance["contamination"]["max"])
	var n := 0
	for i in 150:
		var e := sim.threats._spawn("mimic", Vector2i(8 + i % 8, 8 + i / 8 % 8))
		if e == null:
			continue
		sim.tick += 1
		sim.threats.damage_enemy(e, 9999.0, "generic", sim.colonists.list[0])
	for g: GearItem in sim.equipment.instances.values():
		if g.rarity != "common":
			n += 1
	return n


func test_pollution_raises_rarity() -> void:
	var clean := _rare_share(0.0)
	var dirty := _rare_share(0.9)
	assert_true(dirty > clean, "tainted: %d > %d" % [dirty, clean])



func test_no_loot_before_min_day() -> void:
	var sim := _scene(5)
	sim.tick = 2 * sim.ticks_per_day
	sim.defs.enemies["brute"]["loot"]["chance"] = 1.0
	var e := sim.threats._spawn("brute", Vector2i(8, 8))
	sim.threats.damage_enemy(e, 9999.0, "generic", sim.colonists.list[0])
	assert_eq(sim.equipment.instances.size(), 0, "grace period")


## F3a: inmates start with a shiv; these tests count gear instances / item ids, so they begin from an empty armoury.
func _bare(sim: Simulation) -> Simulation:
	sim.equipment.instances.clear()
	sim.equipment.equipped.clear()
	sim.equipment.totals.clear()
	sim.equipment._next_id = 1
	sim.colonists._f3a_pending.clear()
	return sim
