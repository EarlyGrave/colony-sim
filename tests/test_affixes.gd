extends TestCase
## E3 affixes: rarity counts, caps, tags, determinism, ilvl tiers.

const Report := preload("res://tools/affix_report.gd")


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_rarity_counts_caps_and_dups() -> void:
	var defs := Defs.get_default()
	var rules: Dictionary = defs.affixes["rules"]
	var rng := _rng(7)
	for rarity: String in defs.equipment["rarity"]:
		for base: String in ["rifle", "plasma_blade", "smg", "kevlar_vest", "helmet"]:
			for i in 40:
				var r := AffixRoller.roll(defs, base, rarity, i % 15, rng)
				assert_eq(r.size(), int(defs.equipment["rarity"][rarity]["affixes"]), "%s %s" % [rarity, base])
				var seen := {}
				var pos := {"prefix": 0, "suffix": 0}
				var grp := {}
				for a in r:
					assert_false(seen.has(a[0]), "dup")
					seen[a[0]] = true
					var d: Dictionary = defs.affixes["affixes"][a[0]]
					pos[d["pos"]] += 1
					var g := AffixRoller.group_of(defs.affixes, a[0])
					grp[g] = int(grp.get(g, 0)) + 1
				assert_true(pos["prefix"] <= int(rules["max_prefix"]) and pos["suffix"] <= int(rules["max_suffix"]))
				for g: String in grp:
					assert_true(grp[g] <= int(rules["max_per_group"][g]), "group cap")


func test_tags_respected() -> void:
	var defs := Defs.get_default()
	var rng := _rng(3)
	for i in 100:
		for a in AffixRoller.roll(defs, "kevlar_vest", "legendary", 10, rng):
			assert_true(["armor_phys", "armor_energy", "flat_phys", "flat_energy", "max_hp", "move_speed", "durability_max"].has(a[0]), a[0])
		for a in AffixRoller.roll(defs, "prison_shiv", "legendary", 10, rng):
			assert_false(["ammo_eff", "pen_pct_energy"].has(a[0]), a[0])


func test_same_seed_same_item() -> void:
	var defs := Defs.get_default()
	assert_eq(AffixRoller.roll(defs, "smg", "epic", 6, _rng(9)), AffixRoller.roll(defs, "smg", "epic", 6, _rng(9)))
	var out: Array = []
	for k in 2:
		var sim := make_sim(5, false, 40, 40, peaceful_defs())
		var c := sim.colonists.spawn(Vector2i(5, 5))
		var id := sim.give_gear(c.id, "plasma_blade", "legendary", 12)
		out.append([sim.equipment.instances[id].affixes, sim.equipment.instances[id].stats])
	assert_eq(out[0], out[1])
	assert_eq((out[0][0] as Array).size(), 4)


func test_tier_by_ilvl() -> void:
	var defs := Defs.get_default()
	var rules: Dictionary = defs.affixes["rules"]
	assert_eq(AffixRoller.tier_for(rules, 0), 0)
	assert_eq(AffixRoller.tier_for(rules, 4), 0)
	assert_eq(AffixRoller.tier_for(rules, 5), 1)
	assert_eq(AffixRoller.tier_for(rules, 99), 2)
	var rng := _rng(5)
	for i in 60:
		for a in AffixRoller.roll(defs, "kevlar_vest", "rare", 0, rng):
			var rg: Array = defs.affixes["affixes"][a[0]]["tiers"][0]
			assert_true(a[1] >= float(rg[0]) - 0.0001 and a[1] <= float(rg[1]) + 0.0001, "tier0 range %s" % a[0])
		for a in AffixRoller.roll(defs, "kevlar_vest", "rare", 20, rng):
			var rg2: Array = defs.affixes["affixes"][a[0]]["tiers"][2]
			assert_true(a[1] >= float(rg2[0]) - 0.0001 and a[1] <= float(rg2[1]) + 0.0001, "tier2 range %s" % a[0])


func test_stats_include_affixes_and_common_has_none() -> void:
	var sim := make_sim(5, false, 40, 40, peaceful_defs())
	var c := sim.colonists.spawn(Vector2i(5, 5))
	var id := sim.give_gear(c.id, "kevlar_vest", "common")
	assert_eq(sim.equipment.instances[id].affixes.size(), 0)
	var id2 := sim.give_gear(c.id, "kevlar_vest", "legendary", 10)
	var g: GearItem = sim.equipment.instances[id2]
	for a in g.affixes:
		assert_true(float(g.stats.get(a[0], 0.0)) >= float(a[1]) - 0.0001)


func test_legendary_split_balanced() -> void:
	var defs := Defs.get_default()
	var s: Dictionary = Report.stats(defs, "legendary", 1000, 10)
	assert_eq(s["dups"], 0)
	assert_eq(s["count_bad"], 0)
	assert_true(s["offense_pct"] >= 40.0 and s["offense_pct"] <= 60.0, "split %f" % s["offense_pct"])
