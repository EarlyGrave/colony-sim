extends TestCase
## F3a: every inmate starts with a prison shiv as a real GearItem; wave-survival reward is data-driven and rng-isolated.


func _scene(seed_v: int) -> Simulation:
	var sim := make_sim(seed_v, false, 40, 40, peaceful_defs())
	sim.colonists.spawn(Vector2i(5, 5))
	sim.tick = 7 * sim.ticks_per_day
	return sim


func _count(sim: Simulation, base: String) -> int:
	var n := 0
	for g: GearItem in sim.equipment.instances.values():
		if g.base == base:
			n += 1
	return n


func test_every_inmate_has_a_shiv() -> void:
	var sim := make_sim(3)
	var alive := 0
	for c in sim.colonists.list:
		alive += 1
		var owned := 0
		for g: GearItem in sim.equipment.instances.values():
			if g.owner == c.id and g.base == "prison_shiv" and g.rarity == "common":
				owned += 1
		assert_eq(owned, 1, "inmate %d owns one shiv" % c.id)
	assert_true(alive > 0)
	sim.step()
	for c in sim.colonists.list:
		var worn: int = sim.equipment.equipped.get(c.id, {}).get("weapon", -1)
		if c.engineer:
			assert_eq(worn, -1, "engineers keep the rifle")
		else:
			assert_true(worn >= 0, "shiv worn")


func test_wave_reward_gives_item_and_keeps_rng() -> void:
	var sim := _scene(5)
	sim.defs.gear["_wave_reward"]["chance"] = 1.0
	var before_items := sim.equipment.instances.size()
	var st := sim.rng.state
	var id := sim.threats._f3a_wave_reward()
	assert_true(id >= 0, "rewarded")
	assert_eq(sim.equipment.instances.size(), before_items + 1)
	assert_eq(sim.rng.state, st, "sim.rng untouched")
	var g: GearItem = sim.equipment.instances[id]
	assert_true(g.rarity == "common" or g.rarity == "uncommon")
	assert_true(sim.defs.gear["_wave_reward"]["bases"].has(g.base))


func test_wave_reward_deterministic_and_off_at_zero_chance() -> void:
	var a := _scene(11)
	var b := _scene(11)
	a.defs.gear["_wave_reward"]["chance"] = 1.0
	b.defs.gear["_wave_reward"]["chance"] = 1.0
	var ga: GearItem = a.equipment.instances[a.threats._f3a_wave_reward()]
	var gb: GearItem = b.equipment.instances[b.threats._f3a_wave_reward()]
	assert_eq(ga.base + ga.rarity, gb.base + gb.rarity)
	var z := _scene(11)
	z.defs.gear["_wave_reward"]["chance"] = 0.0
	assert_eq(z.threats._f3a_wave_reward(), -1)
	assert_eq(_count(z, "kevlar_vest"), 0)


func test_wave_reward_respects_min_day() -> void:
	var sim := _scene(5)
	sim.defs.gear["_wave_reward"]["chance"] = 1.0
	sim.tick = 0
	assert_eq(sim.threats._f3a_wave_reward(), -1)
