extends TestCase
## PW2: trait system (rarity draw, excludes, block_only, acquired traits, hooks).


func _gen(sim: Simulation, n: int) -> Array[Colonist]:
	var out: Array[Colonist] = []
	for i in n:
		out.append(ColonistGenerator.generate(sim, Vector2i(5, 5)))
	return out


func test_all_traits_have_desc() -> void:
	var sim := make_sim(3, true, 24, 24, peaceful_defs())
	var t: Dictionary = sim.defs.traits["traits"]
	assert_true(t.size() >= 23, "20 innate + 3 acquired")
	for id: String in t:
		assert_true(str(t[id].get("desc", "")) != "", id + " desc")
		assert_true(t[id].has("rarity"), id + " rarity")


func test_excludes_and_block_only_over_500() -> void:
	var sim := make_sim(11, true, 24, 24, peaceful_defs())
	var counts := {"common": 0, "uncommon": 0, "rare": 0}
	var total := 0
	for c in _gen(sim, 500):
		var ts: Array = c.bio["traits"]
		assert_true(ts.size() <= 2)
		for t: String in ts:
			var d: Dictionary = sim.traits.def(t)
			assert_false(bool(d.get("acquired", false)), "no acquired at birth")
			if d.has("block_only"):
				assert_eq(sim.blocks.block_of(c), str(d["block_only"]), t + " block_only")
			for o: String in ts:
				assert_false((d["excludes"] as Array).has(o), t + " excludes " + o)
			counts[str(d["rarity"])] += 1
			total += 1
	assert_true(total > 300)
	assert_true(counts["common"] > counts["uncommon"] and counts["uncommon"] > counts["rare"], str(counts))


func test_rarity_frequency_roughly_matches_weights() -> void:
	var sim := make_sim(21, true, 24, 24, peaceful_defs())
	var per := {}
	for c in _gen(sim, 800):
		for t: String in c.bio["traits"]:
			per[t] = int(per.get(t, 0)) + 1
	var ratio := float(per.get("strong", 0)) / maxf(1.0, float(per.get("cold_blood", 1)))
	assert_true(ratio > 3.0 and ratio < 12.0, "ratio " + str(ratio))


func test_hardened_after_rescue_once() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	var c := ColonistGenerator.generate(sim, Vector2i(5, 5))
	c.bio["traits"] = []
	sim.colonists.add(c)
	sim.bus.colonist_rescued.emit(c.id, 0)
	assert_true(sim.traits.has(c, "hardened"))
	sim.bus.colonist_rescued.emit(c.id, 0)
	assert_eq((c.bio["traits"] as Array).count("hardened"), 1)
	assert_false(sim.traits.grant(c, "settled"), "acquired cap 1")


func test_resigned_freezes_despair() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	var c := ColonistGenerator.generate(sim, Vector2i(5, 5))
	c.bio["traits"] = []
	sim.colonists.add(c)
	assert_true(sim.traits.grant(c, "resigned"))
	assert_true(sim.traits.has_tag(c, "despair_frozen"))
	assert_true(sim.traits.mod(c, "mood_base") > 0.0)


func test_mod_and_alias() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	var c := ColonistGenerator.generate(sim, Vector2i(5, 5))
	c.bio["traits"] = ["lazy", "cold_blood"]
	assert_eq(sim.traits.def("lazy")["name"], "Slow Burner")
	assert_true(absf(sim.traits.mod(c, "mood_base") - (6.0)) < 0.001)
	assert_true(absf(sim.traits.mod(c, "flee_threshold") - (-1.0)) < 0.001)


func test_determinism() -> void:
	var a := make_sim(9, true, 24, 24, peaceful_defs())
	var b := make_sim(9, true, 24, 24, peaceful_defs())
	var la := _gen(a, 30)
	var lb := _gen(b, 30)
	for i in 30:
		assert_eq(la[i].bio["traits"], lb[i].bio["traits"])


# region F3c: every formerly text-only stat is read by a consumer
func _solo(trait_id: String) -> Array:
	var sim := make_sim(21, true, 24, 24, peaceful_defs())
	var c: Colonist = sim.colonists.list[0]
	c.bio["traits"] = [trait_id] if trait_id != "" else []
	return [sim, c]


func test_f3c_carry() -> void:
	var r := _solo("strong")
	assert_eq(r[0].traits.carry_cap(r[1], 10), 13)
	r[1].bio["traits"] = []
	assert_eq(r[0].traits.carry_cap(r[1], 10), 10)


func test_f3c_xp_mult() -> void:
	var r := _solo("quick_study")
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	var skill: String = c.skills.levels.keys()[0]
	var a0 := c.skills.xp_total(sim.defs, skill)
	sim.progression.award(c, skill, 4.0, "t", false)
	var gain_q := c.skills.xp_total(sim.defs, skill) - a0
	c.bio["traits"] = []
	var b0 := c.skills.xp_total(sim.defs, skill)
	sim.progression.award(c, skill, 4.0, "t", false)
	var gain_n := c.skills.xp_total(sim.defs, skill) - b0
	assert_gt(gain_q, gain_n * 1.2)
	c.bio["traits"] = ["frail"]
	assert_near(sim.traits.xp_mult(c, "crafting"), 1.15, 0.001)
	assert_near(sim.traits.xp_mult(c, "mining"), 1.0, 0.001)


func test_f3c_hit() -> void:
	var r := _solo("hasty")
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	var w: Dictionary = sim.defs.weapons["weapons"][c.combat.weapon]
	var with_t := sim.combat.hit_chance(c, w, 2.0)
	c.bio["traits"] = []
	var without := sim.combat.hit_chance(c, w, 2.0)
	assert_lt(with_t, without)
	assert_near(without - with_t, 0.08, 0.001)


func test_f3c_night_day() -> void:
	var r := _solo("night_owl")
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	var seen_night := false
	var seen_day := false
	for t in range(0, sim.ticks_per_day, 20):
		sim.tick = t
		var night := sim.clock.is_night()
		assert_near(sim.traits.shift_mult(c), 1.15 if night else 0.9, 0.001)
		seen_night = seen_night or night
		seen_day = seen_day or not night
	assert_true(seen_night and seen_day)


func test_f3c_mutation_risk() -> void:
	var r := _solo("essence_nose")
	assert_near(r[0].traits.mutation_mult(r[1]), 1.2, 0.001)
	r[1].bio["traits"] = []
	assert_near(r[0].traits.mutation_mult(r[1]), 1.0, 0.001)


func test_f3c_standing_gain() -> void:
	var r := _solo("loud_mouth")
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	sim.blocks.cfg["enabled"] = true
	var b := sim.blocks.block_of(c)
	sim.blocks.standing[b] = 50.0
	sim.blocks.on_installment_paid(c)
	var with_t: float = sim.blocks.standing_of(b) - 50.0
	c.bio["traits"] = []
	sim.blocks.standing[b] = 50.0
	sim.blocks.on_installment_paid(c)
	var without: float = sim.blocks.standing_of(b) - 50.0
	assert_gt(without, 0.0)
	assert_near(with_t, without * 1.5, 0.001)


func test_f3c_armor_flat() -> void:
	var r := _solo("thick_hide")
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	sim.combat.resum(c)
	assert_near(sim.combat.def_of(c)[StatBlock.FLAT_PHYS], 1.0, 0.001)
	c.bio["traits"] = []
	sim.combat.resum(c)
	assert_near(sim.combat.def_of(c)[StatBlock.FLAT_PHYS], 0.0, 0.001)
# endregion
