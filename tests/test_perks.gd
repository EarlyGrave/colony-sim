extends TestCase
## Perks: data validity, points, learning rules, actives, caps, respec, replay.
const Scenario := preload("res://tests/scenario.gd")


func _sim_with_colonist() -> Array:
	var sim := make_sim(5, false, 20, 20, peaceful_defs())
	var c := sim.colonists.spawn(Vector2i(4, 4))
	for s: String in c.skills.levels:
		c.skills.levels[s] = 10
	c.skills.join_levels.clear()  # tests grant levels directly: baseline 0
	return [sim, c]


func test_json_valid() -> void:
	var data: Dictionary = Defs.get_default().perks
	var perks: Array = data["perks"]
	assert_eq(perks.size(), 80)
	var by_id: Dictionary = {}
	var per_skill: Dictionary = {}
	for p: Dictionary in perks:
		assert_false(by_id.has(p["id"]), "duplicate id " + str(p["id"]))
		by_id[p["id"]] = p
		per_skill[p["skill"]] = int(per_skill.get(p["skill"], 0)) + 1
		assert_true(int(p["skill_level"]) >= 1 and int(p["skill_level"]) <= 10)
		assert_true(["passive", "active"].has(p["type"]))
		if p["type"] == "active":
			assert_gt(float(p["cooldown_ticks"]), 0.0)
			assert_true(p["active"].has("id"))
		else:
			assert_false(p["effects"].is_empty())
	assert_eq(per_skill.size(), 8)
	for s: String in per_skill:
		assert_eq(per_skill[s], 10)
		assert_true(Defs.get_default().skills["skills"].has(s))
	for p: Dictionary in perks:
		var tier := int(p["tier"])
		assert_eq(int(p["skill_level"]), tier * 2)
		assert_eq(p["excludes"].size(), 1)
		for x: String in p["excludes"]:
			assert_true(by_id.has(x))
			assert_true(by_id[x]["excludes"].has(p["id"]), "asymmetric exclude " + x)
			assert_eq(int(by_id[x]["tier"]), tier)
		assert_eq(p["requires_any"].is_empty(), tier == 1)
		for r: String in p["requires_any"]:
			assert_eq(int(by_id[r]["tier"]), tier - 1)
			assert_eq(by_id[r]["skill"], p["skill"])
		for r: String in p["requires"]:
			assert_true(by_id.has(r), "missing prereq " + r)
			assert_eq(by_id[r]["skill"], p["skill"])
			assert_lt(float(by_id[r]["skill_level"]), float(p["skill_level"]) + 0.5)
	# No cycles: depth-first walk with a visiting set.
	for id: String in by_id:
		var seen: Dictionary = {}
		var stack: Array = [id]
		while not stack.is_empty():
			var cur: String = stack.pop_back()
			for r: String in by_id[cur]["requires"]:
				assert_false(r == id or seen.has(r), "cycle at " + id)
				seen[r] = true
				stack.append(r)


func test_learn_rejections() -> void:
	var r := _sim_with_colonist()
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	c.skills.levels["operating"] = 1
	assert_eq(sim.perks.can_learn(c, "nope"), "unknown_perk")
	assert_eq(sim.perks.can_learn(c, "steady_operator"), "level")
	c.skills.levels["operating"] = 4
	assert_eq(sim.perks.can_learn(c, "clean_work"), "requires")  # needs a tier 1 perk
	assert_true(sim.learn_perk(c.id, "steady_operator"))
	assert_eq(sim.perks.can_learn(c, "steady_operator"), "already_learned")
	assert_false(sim.learn_perk(c.id, "steady_operator"))
	assert_eq(sim.perks.can_learn(c, "careful_hands"), "excluded")
	assert_true(sim.learn_perk(c.id, "clean_work"))
	assert_eq(sim.perks.can_learn(c, "overclock"), "excluded")
	# Level 4 = 2 points, both spent; tier 3 needs level 6 anyway.
	assert_eq(sim.perks.points_available(c, "operating"), 0)
	assert_eq(sim.perks.can_learn(c, "filters"), "level")
	c.skills.levels["operating"] = 6
	assert_eq(sim.perks.can_learn(c, "tuned_rig"), "")
	assert_true(sim.learn_perk(c.id, "filters"))
	assert_eq(sim.perks.can_learn(c, "tuned_rig"), "excluded")
	# requires_any follows the picked branch only: tier 4 accepts either tier 3 perk.
	c.skills.levels["operating"] = 8
	assert_true(sim.learn_perk(c.id, "night_shift"))
	# Tier skipping: no tier 2 perk in melee.
	assert_eq(sim.perks.can_learn(c, "berserker"), "requires")
	c.alive = false
	assert_eq(sim.perks.can_learn(c, "battle_cry"), "dead")


func test_no_points_and_respec_reopens() -> void:
	var r := _sim_with_colonist()
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	c.skills.levels["mining"] = 2
	assert_eq(sim.perks.points_available(c, "mining"), 1)
	assert_true(sim.learn_perk(c.id, "miner_pace"))
	assert_eq(sim.perks.points_available(c, "mining"), 0)
	# Level 3 still gives no new point; level 4 does but the tier 2 perk needs it.
	c.skills.levels["mining"] = 3
	assert_eq(sim.perks.points_available(c, "mining"), 0)
	# Reachable no_points: level 10 skill, five points spent.
	c.skills.levels["mining"] = 10
	for id: String in ["quiet_dig", "hardhat", "sprint", "ghost_miner"]:
		assert_true(sim.learn_perk(c.id, id), id)
	assert_eq(sim.perks.points_available(c, "mining"), 0)
	# In a consistent tree every perk left is excluded; no_points is a safety net.
	assert_eq(sim.perks.can_learn(c, "pack_mule"), "excluded")
	assert_eq(sim.perks.can_learn(c, "motherlode"), "excluded")
	assert_eq(sim.perks.can_learn(c, "steady_swing"), "excluded")
	# Respec re-opens the excluded alternative.
	var cell := Vector2i(10, 10)
	sim.set_zone(cell, "stockpile")
	var cost := sim.perks.respec_cost()
	sim.items.add_at(cell, str(cost["item"]), int(cost["count"]))
	assert_true(sim.respec_perks(c.id))
	assert_eq(sim.perks.points_available(c, "mining"), 5)
	assert_eq(sim.perks.can_learn(c, "steady_swing"), "")
	assert_eq(sim.perks.can_learn(c, "quiet_dig"), "requires")


func test_points_formula() -> void:
	var r := _sim_with_colonist()
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	c.skills.levels["plants"] = 4
	assert_eq(sim.perks.points_available(c, "plants"), 2)
	assert_true(sim.learn_perk(c.id, "green_thumb"))
	assert_true(sim.learn_perk(c.id, "bountiful"))
	assert_false(sim.learn_perk(c.id, "fast_farmer"))  # needs level 6
	c.skills.levels["plants"] = 6
	assert_true(sim.learn_perk(c.id, "patient_gardener"))
	assert_eq(sim.perks.points_available(c, "plants"), 0)
	c.skills.levels["plants"] = 3
	assert_eq(sim.perks.points_available(c, "plants"), 0)
	assert_eq(sim.perks.can_learn(c, "double_harvest"), "level")
	c.skills.levels["plants"] = 10
	assert_eq(sim.perks.points_available(c, "plants"), 2)


func test_point_signal() -> void:
	var r := _sim_with_colonist()
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	var got: Array = []
	sim.bus.perk_point_available.connect(func(id: int, s: String, n: int) -> void: got.append([id, s, n]))
	c.skills.levels["mining"] = 2
	c.skills.xp["mining"] = 0.0
	c.skills.passions["mining"] = Skills.Passion.NONE
	if c.skills.add_xp(sim.defs, "mining", 1.0e6):
		sim.bus.skill_leveled.emit(c.id, "mining", c.skills.level("mining"))
	assert_eq(got.size(), 1)
	assert_eq(got[0][1], "mining")
	assert_eq(got[0][2], 5)


func test_use_cooldown_and_buff_expiry() -> void:
	var r := _sim_with_colonist()
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	for id: String in ["miner_pace", "quiet_dig", "hardhat", "sprint"]:
		assert_true(sim.learn_perk(c.id, id), id)
	assert_near(sim.perks.mod(c, "mining_speed"), 0.15, 0.0001)
	assert_near(sim.perks.mod(c, "threat_attract"), -0.2, 0.0001)
	assert_near(sim.perks.mod(c, "move_speed"), 0.0, 0.0001)
	assert_false(sim.use_perk(c.id, "miner_pace"))  # passive
	assert_true(sim.use_perk(c.id, "sprint"))
	assert_near(sim.perks.mod(c, "move_speed"), 0.6, 0.0001)
	assert_false(sim.use_perk(c.id, "sprint"))  # cooldown
	assert_gt(float(sim.perks.cooldown_left(c, "sprint")), 0.0)
	var dur := int(sim.perks.perk_def("sprint")["active"]["params"]["duration"])
	sim.run_ticks(dur + 1)
	assert_near(sim.perks.mod(c, "move_speed"), 0.0, 0.0001)
	assert_false(sim.use_perk(c.id, "sprint"))
	sim.run_ticks(int(sim.perks.perk_def("sprint")["cooldown_ticks"]))
	assert_true(sim.use_perk(c.id, "sprint"))


func test_flags_and_effects() -> void:
	var r := _sim_with_colonist()
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	for id: String in ["steady_operator", "clean_work", "filters", "cold_start"]:
		assert_true(sim.learn_perk(c.id, id), id)
	assert_false(sim.perks.consume_flag(c, "no_waste_next_batch"))
	assert_true(sim.use_perk(c.id, "cold_start"))
	assert_true(sim.perks.consume_flag(c, "no_waste_next_batch"))
	assert_false(sim.perks.consume_flag(c, "no_waste_next_batch"))
	for id: String in ["steady_aim", "quick_draw", "sniper", "aimed_shot"]:
		assert_true(sim.learn_perk(c.id, id), id)
	assert_true(sim.use_perk(c.id, "aimed_shot"))
	assert_near(sim.perks.mod(c, "hit_chance"), 0.8, 0.0001)
	assert_true(sim.perks.consume_flag(c, "aimed_shot"))
	assert_near(sim.perks.mod(c, "hit_chance"), 0.2, 0.0001)


func test_cap() -> void:
	var r := _sim_with_colonist()
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	for id: String in ["steady_operator", "clean_work", "filters"]:
		assert_true(sim.learn_perk(c.id, id))
	assert_near(sim.perks.mod(c, "waste_mult"), -0.15, 0.0001)
	assert_near(sim.perks.mod(c, "contamination_per_batch"), -0.25, 0.0001)
	sim.perks.state_of(c).add_buff("test", {"waste_mult": -0.5, "contamination_per_batch": -0.5}, -1)
	assert_near(sim.perks.mod(c, "waste_mult"), -0.4, 0.0001)
	assert_near(sim.perks.mod(c, "contamination_per_batch"), -0.4, 0.0001)


func test_instant_tend() -> void:
	var r := _sim_with_colonist()
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	for id: String in ["gentle_hands", "fast_healer", "field_surgeon", "instant_tend"]:
		assert_true(sim.learn_perk(c.id, id), id)
	assert_false(sim.use_perk(c.id, "instant_tend"))  # nobody hurt: no cooldown spent
	sim.health.apply_damage(c, 5.0)
	assert_true(sim.use_perk(c.id, "instant_tend"))
	for i in c.health.injuries:
		assert_true(i.tended)


func test_respec() -> void:
	var r := _sim_with_colonist()
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	assert_true(sim.learn_perk(c.id, "steady_operator"))
	assert_eq(sim.perks.points_available(c, "operating"), 4)
	assert_false(sim.respec_perks(c.id))  # no essence
	var cell := Vector2i(10, 10)
	sim.set_zone(cell, "stockpile")
	var cost := sim.perks.respec_cost()
	sim.items.add_at(cell, str(cost["item"]), int(cost["count"]) + 1)
	assert_true(sim.respec_perks(c.id))
	assert_false(sim.perks.has(c, "steady_operator"))
	assert_eq(sim.perks.points_available(c, "operating"), 5)
	assert_eq(sim.items.count_stored(str(cost["item"])), 1)
	assert_false(sim.respec_perks(c.id))  # nothing to forget


## Defs where everybody joins at level 0 and levels come after one xp.
func _fast_defs() -> Defs:
	var d := peaceful_defs()
	d.skills["init"]["level_max"] = 0
	d.skills["xp_table"] = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
	return d


func _play(sim: Simulation) -> void:
	var c: Colonist = sim.colonists.list[0]
	Scenario.designate_nearest_deposits(sim, 10)
	sim.run_ticks(600)
	var skill := ""
	for s: String in c.skills.levels:
		if c.skills.level(s) >= 2:
			skill = s
			break
	assert_ne(skill, "")
	var first: String = sim.perks.perks_of_skill(skill)[0]
	sim.run_ticks(50)
	sim.learn_perk(c.id, first)
	sim.run_ticks(50)
	sim.learn_perk(c.id, first)  # duplicate, recorded but rejected


func test_save_load_replay() -> void:
	var sim := make_sim(21, true, 24, 24, _fast_defs())
	_play(sim)
	var c: Colonist = sim.colonists.list[0]
	assert_true(c.perks != null)
	assert_eq(c.perks.learned.size(), 1)
	var res := SaveGame.load_json(SaveGame.to_json(sim), make_bus(), _fast_defs())
	assert_true(res["ok"], str(res["error"]))
	var sim2: Simulation = res["sim"]
	_sims.append(sim2)
	assert_eq(sim2.colonists.list[0].perks.learned, c.perks.learned)
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))


func test_deterministic() -> void:
	var a := make_sim(33, true, 24, 24, _fast_defs())
	var b := make_sim(33, true, 24, 24, _fast_defs())
	_play(a)
	_play(b)
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b))
