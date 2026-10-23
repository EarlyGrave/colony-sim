extends TestCase
## Traits v3 (data/traits_v3.json, sim/colonists/trait_system_v3.gd): the module is exercised
## directly; the live sim never loads it while balance.traits_v3_enabled is false.


func _sys(sim: Simulation) -> TraitSystemV3:
	return TraitSystemV3.new(sim)


func _gen(sim: Simulation, n: int) -> Array[Colonist]:
	var out: Array[Colonist] = []
	for i in n:
		out.append(ColonistGenerator.generate(sim, Vector2i(5, 5)))
	return out


func test_flag_off_means_not_loaded() -> void:
	var sim := make_sim(1, true, 24, 24, peaceful_defs())
	assert_false(bool(sim.defs.balance.get("traits_v3_enabled", false)), "flag must be off")
	assert_true(sim.defs.traits_v3.is_empty(), "Defs must not load traits_v3.json while the flag is off")
	assert_true(sim.traits_v3 == null, "Simulation.traits_v3 stays null while the flag is off")
	for c in _gen(sim, 5):
		assert_false(c.bio.has("traits_v3"), "generator untouched")


func test_data_valid_and_counts() -> void:
	var ts := TraitSystemV3.new(null)
	var errs := ts.validate()
	assert_eq(errs.size(), 0, "\n".join(errs))
	var n := ts.ids().size()
	assert_true(n >= 50 and n <= 70, "50..70 traits, got %d" % n)
	var per := {}
	for id in ts.ids():
		var cat := ts.category(id)
		per[cat] = int(per.get(cat, 0)) + 1
	for cat in TraitSystemV3.CATEGORIES:
		assert_true(int(per.get(cat, 0)) >= 8, cat + " has >= 8 traits: " + str(per))
	# excludes are symmetric in effect (conflict checks both ways), so one-sided data is fine,
	# but every excluded id must exist and never exclude itself
	for id in ts.ids():
		for ex in ts.def(id).get("excludes", []):
			assert_ne(str(ex), id, id + " excludes itself")


func test_icons_exist_for_every_trait() -> void:
	var ts := TraitSystemV3.new(null)
	for id in ts.ids():
		var p := ts.icon_path(id)
		assert_true(FileAccess.file_exists(p), "missing icon " + p)
		assert_true(FileAccess.file_exists(p + ".import"), "missing .import for " + p)


func test_birth_roll_fixed_draws_and_slots() -> void:
	var sim := make_sim(7, true, 24, 24, peaceful_defs())
	var ts := _sys(sim)
	var draws := int(ts.cfg["slots"]["innate_max"]) + 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var ref := RandomNumberGenerator.new()
	ref.seed = 4242
	var rarity := {}
	var with_social := 0
	for i in 500:
		var chosen := ts.roll_birth(rng, {"block": "lifer"})
		for k in draws:
			ref.randf()
		assert_eq(rng.state, ref.state, "fixed draw count")
		var n_bg := 0
		var n_innate := 0
		for id in chosen:
			var cat := ts.category(id)
			if cat == "background":
				n_bg += 1
			if TraitSystemV3.INNATE_CATS.has(cat):
				n_innate += 1
			if cat == "social":
				with_social += 1
			rarity[ts.def(id)["rarity"]] = int(rarity.get(ts.def(id)["rarity"], 0)) + 1
			for o in chosen:
				if o != id:
					assert_false((ts.def(id).get("excludes", []) as Array).has(o), id + " with " + o)
					if ts.def(id).has("group"):
						assert_ne(str(ts.def(id)["group"]), str(ts.def(o).get("group", "")), "group clash " + id + "/" + o)
		assert_eq(n_bg, 1, "exactly one Charge")
		assert_true(n_innate <= int(ts.cfg["slots"]["innate_max"]))
	assert_true(with_social > 50 and with_social < 250, "social at birth ~30%%: %d" % with_social)
	assert_true(rarity["common"] > rarity["uncommon"] and rarity["uncommon"] > rarity["rare"], str(rarity))


func test_birth_deterministic_and_apply() -> void:
	var sim := make_sim(9, true, 24, 24, peaceful_defs())
	var ts := _sys(sim)
	var c := _gen(sim, 1)[0]
	var r1 := RandomNumberGenerator.new()
	r1.seed = 77
	var hp0 := c.max_hp
	var a := ts.apply_birth(c, r1, {"block": "clerk"})
	var r2 := RandomNumberGenerator.new()
	r2.seed = 77
	var b := ts.roll_birth(r2, {"block": "clerk"})
	assert_eq(a, b, "same seed, same traits")
	assert_eq(ts.list(c), a)
	assert_near(c.max_hp, hp0 + ts.mod(c, "max_hp"), 0.001)
	assert_true(c.bio["trait_log"].size() == a.size())


func test_conflicts_and_slot_caps() -> void:
	var sim := make_sim(3, true, 24, 24, peaceful_defs())
	var ts := _sys(sim)
	var c := _gen(sim, 1)[0]
	assert_true(ts.add(c, "t_stoic"))
	assert_eq(ts.can_add(c, "t_volatile"), "excludes:t_stoic")
	assert_eq(ts.can_add(c, "t_stoic"), "owned")
	assert_eq(ts.can_add(c, "t_nope"), "unknown")
	assert_true(ts.add(c, "t_methodical"))
	assert_eq(ts.can_add(c, "t_reckless"), "excludes:t_methodical")
	assert_eq(ts.conflict(["t_hulking"], "t_wiry"), "excludes:t_hulking")
	assert_eq(ts.conflict(["t_insomniac"], "t_paranoid"), "")
	assert_eq(ts.conflict(["t_fast_healer", "t_charge_debt"], "t_charge_fraud"), "slot:background")
	assert_eq(ts.can_add(c, "t_wiry"), "slot:innate", "innate_max 2")
	assert_true(ts.add(c, "t_charge_fraud"))
	assert_eq(ts.can_add(c, "t_charge_murder"), "slot:background")
	assert_true(ts.add(c, "t_glowtouched", "test"))
	assert_true(ts.add(c, "t_black_veins", "test"))
	assert_eq(ts.can_add(c, "t_essence_hum"), "slot:mutation")
	assert_true(ts.add(c, "t_settled"))
	assert_eq(ts.can_add(c, "t_marked"), "slot:acquired")
	assert_true(ts.remove(c, "t_settled"))
	assert_eq(ts.can_add(c, "t_marked"), "")
	assert_true(ts.has_tag(c, "mutated"))


func test_essence_ladder_and_replaces() -> void:
	var sim := make_sim(3, true, 24, 24, peaceful_defs())
	var ts := _sys(sim)
	var c := _gen(sim, 1)[0]
	assert_eq(ts.event(c, "exposure_illness"), ["+t_glowtouched"])
	assert_eq(ts.event(c, "exposure_illness"), [])
	assert_eq(ts.event(c, "exposure_illness"), ["-t_glowtouched", "+t_second_skin"])
	assert_false(ts.has(c, "t_glowtouched"))
	for i in 2:
		ts.event(c, "exposure_illness")
	assert_eq(ts.event(c, "exposure_illness"), ["-t_second_skin", "+t_hollow"])
	assert_eq(ts.list(c), ["t_hollow"], "lower rungs never come back")
	assert_eq(ts.event(c, "exposure_illness"), [], "ladder done")
	assert_true(ts.has_tag(c, "despair_frozen"))
	assert_near(ts.thought_mult(c, "injured", -5.0), 0.0, 0.001, "Hollow ignores thoughts")
	# echo needs glowtouched (gone by now): never granted
	assert_eq(ts.event(c, "mimic_met"), [])


func test_scars_gain_lose_and_reset() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	var ts := _sys(sim)
	var c := _gen(sim, 1)[0]
	for i in 29:
		assert_eq(ts.event(c, "calm_day"), [])
	assert_eq(ts.event(c, "calm_day"), ["+t_settled"])
	assert_eq(ts.event(c, "break"), ["-t_settled"], "break removes Settled and resets calm")
	assert_eq(ts.counter(c, "calm_day"), 0)
	for i in 4:
		ts.event(c, "despair_day")
	ts.event(c, "despair_relief")
	assert_eq(ts.counter(c, "despair_day"), 0, "reset_on")
	for i in 5:
		ts.event(c, "despair_day")
	assert_true(ts.has(c, "t_resigned"))
	assert_eq(ts.event(c, "rescued"), ["+t_hardened"])
	assert_near(ts.mod(c, "flee_threshold"), -0.3, 0.001)
	assert_eq(ts.event(c, "docked"), ["+t_docked"], "Settled left, so 3 acquired fit")
	for i in 60:
		ts.event(c, "day_served")
	assert_false(ts.has(c, "t_cell_rot"), "acquired_max 3 reached: Cell Rot refused")
	assert_eq(ts.event(c, "period_paid"), ["-t_docked"])


func test_age_ladder_and_shellshock_recovery() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	var ts := _sys(sim)
	var c := _gen(sim, 1)[0]
	for i in 60:
		ts.event(c, "day_served")
	assert_true(ts.has(c, "t_cell_rot"))
	for i in 60:
		ts.event(c, "day_served")
	assert_true(ts.has(c, "t_old_timer") and not ts.has(c, "t_cell_rot"), "Old Timer replaces Cell Rot")
	ts.event(c, "downed_in_wave")
	assert_eq(ts.event(c, "downed_in_wave"), ["+t_shellshocked"])
	for i in 2:
		assert_eq(ts.event(c, "wave_unscathed"), [])
	assert_eq(ts.event(c, "wave_unscathed"), ["-t_shellshocked"])


func test_needs_and_bonds() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	var ts := _sys(sim)
	var cs := _gen(sim, 2)
	var a := cs[0]
	var b := cs[1]
	assert_true(ts.add(a, "t_tunnel_rat"))
	assert_eq(ts.daily_needs(a, {"mined_today": false}), [])
	assert_eq(ts.daily_needs(a, {"mined_today": false}), ["no_tunnel"])
	assert_eq(ts.daily_needs(a, {"mined_today": true}), [])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	assert_false(ts.try_bond(a, b, "t_cellmate", 3, rng), "too few shared days")
	assert_true(ts.bond(a, b, "t_cellmate"))
	assert_eq(ts.partner(a, "t_cellmate"), b.id)
	assert_eq(ts.partner(b, "t_cellmate"), a.id)
	assert_false(ts.bond(a, b, "t_cellmate"), "already bonded")
	assert_true(ts.break_bond(a, "t_cellmate"))
	assert_true(ts.break_bond(b, "t_cellmate"))
	assert_false(ts.has(a, "t_cellmate"))
	assert_eq(ts.partner(a, "t_cellmate"), -1)
	assert_eq(ts.counter(a, "lost_t_cellmate"), 1)
	assert_true(ts.add(b, "t_outcast", "test"))
	assert_false(ts.bond(a, b, "t_cellmate"), "Outcast cannot bond")
	var c3 := _gen(sim, 1)[0]
	ts.add(c3, "t_quiet_one")
	assert_false(ts.bond(a, c3, "t_cellmate"), "Quiet One never bonds")


func test_helpers_and_auras() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	var ts := _sys(sim)
	var cs := _gen(sim, 3)
	var c := cs[0]
	ts.add(c, "t_hulking")
	ts.add(c, "t_stoic")
	assert_eq(ts.carry_cap(c, 10), 14)
	assert_near(ts.target_weight_mult(c), 1.2, 0.001)
	assert_near(ts.thought_mult(c, "injured", -3.0), 0.7, 0.001)
	assert_near(ts.thought_mult(c, "block_proud", 2.0), 0.7, 0.001)
	ts.add(c, "t_charge_cult")
	assert_near(ts.thought_mult(c, "planet_doomed", -8.0), 0.0, 0.001)
	assert_eq(ts.leaning(c)["fight"], 2.0)
	assert_near(ts.refine_speed(c), 0.7, 0.001)
	ts.add(cs[1], "t_gallows_humor")
	ts.add(cs[2], "t_morbid")
	assert_near(ts.aura(c, "mood", cs), 1.0, 0.001, "+2 humor -1 morbid")
	assert_near(ts.aura(cs[1], "mood", cs), 0.0, 0.001, "own aura excluded: +1 cult -1 morbid")
	assert_near(ts.streak_mult(cs[2], 0), 1.0, 0.001)
	ts.add(cs[2], "t_creature_of_habit")
	assert_near(ts.streak_mult(cs[2], 0), 0.85, 0.001)
	assert_near(ts.streak_mult(cs[2], 100), 1.1, 0.001)
	var s := ts.summary(c)
	assert_eq(s.size(), 3)
	assert_eq(s[0]["icon"], "res://assets/sprites/trait_hulking.png")
