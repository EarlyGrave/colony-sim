extends TestCase
## F3d: every skill branch effect (data/skills.json "branches") is read by the system that owns it.
## Branches are chosen through Simulation.choose_branch (level 5), never injected as buffs.


func _sim(seed_value := 9) -> Simulation:
	return make_sim(seed_value, false, 24, 24, peaceful_defs())


## Colonist with all skills at branch level; `skill`/`branch` chosen when branch != "".
func _spawn(sim: Simulation, cell: Vector2i, skill := "", branch := "") -> Colonist:
	var c := sim.colonists.spawn(cell)
	for s: String in c.skills.levels:
		c.skills.levels[s] = 5
	if branch != "":
		assert_true(sim.choose_branch(c.id, skill, branch), "pick " + branch)
	return c


## Damage of each hit over `n` tries (enemy hp reset every try); same seed => same hit rolls.
func _hit_damages(seed_value: int, skill: String, branch: String, weapon: String, n: int) -> Array:
	var sim := _sim(seed_value)
	var c := _spawn(sim, Vector2i(5, 5), skill, branch)
	if weapon != "":
		c.combat.weapon = weapon
		sim.ammo._pouch_init(c)
		c.combat.pouch = 100000
	var e := sim.threats._spawn("brute", Vector2i(6, 5) if weapon == "" else Vector2i(8, 5))
	var out: Array = []
	for i in n:
		e.hp = e.max_hp
		c.combat.next_attack_tick = 0
		sim.combat.try_attack(c, e)
		if e.hp < e.max_hp:
			out.append(snappedf(e.max_hp - e.hp, 0.001))
	return out


func _sum(a: Array) -> float:
	var t := 0.0
	for v in a:
		t += float(v)
	return t


func test_marksman_hit_chance() -> void:
	var sim := _sim()
	var base := _spawn(sim, Vector2i(5, 5))
	var m := _spawn(sim, Vector2i(6, 5), "shooting", "marksman")
	c_hit_check(sim, base, m)


func c_hit_check(sim: Simulation, base: Colonist, m: Colonist) -> void:
	base.combat.weapon = "rifle"
	m.combat.weapon = "rifle"
	var w := sim.combat.weapon_def(base)
	var hb := sim.combat.hit_chance(base, w, 4.0)
	var hm := sim.combat.hit_chance(m, w, 4.0)
	assert_near(hm, minf(hb + 0.12, float(sim.defs.weapons["combat"]["hit_max"])), 0.0001, "marksman +12% hit")


func test_marksman_crit_in_attack() -> void:
	var ctl := _hit_damages(4, "", "", "rifle", 80)
	var mk := _hit_damages(4, "shooting", "marksman", "rifle", 80)
	var distinct := {}
	for d in ctl:
		distinct[d] = true
	assert_eq(distinct.size(), 1, "no crits without the branch")
	distinct.clear()
	for d in mk:
		distinct[d] = true
	assert_eq(distinct.size(), 2, "marksman lands base and x1.5 crit hits")


func test_gunner_burst_shots() -> void:
	var sim := _sim()
	var plain := _spawn(sim, Vector2i(5, 5))
	var gun := _spawn(sim, Vector2i(6, 5), "shooting", "gunner")
	var w := {"burst": {"shots": 3, "gap_ticks": 2}}
	sim.combat._burst_step(plain, w)
	sim.combat._burst_step(gun, w)
	assert_eq(int(sim.combat._pattern[plain.id][0]), 2, "burst of 3: 2 shots left")
	assert_eq(int(sim.combat._pattern[gun.id][0]), 3, "gunner: one more shot left")


func test_warrior_melee_damage() -> void:
	var base := _hit_damages(5, "", "", "", 6)
	var war := _hit_damages(5, "melee", "warrior", "", 6)
	assert_gt(base.size(), 0, "some hits land")
	assert_eq(base.size(), war.size(), "same rolls")
	assert_near(_sum(war), _sum(base) * 1.2, 0.05, "warrior +20% melee damage")


func test_monk_unarmed_damage() -> void:
	var base := _hit_damages(5, "", "", "", 6)
	var monk := _hit_damages(5, "melee", "monk", "", 6)
	assert_gt(base.size(), 0, "some hits land")
	assert_near(_sum(monk), _sum(base) * 1.6, 0.05, "monk +60% unarmed damage")


func _sow_ticks(sim: Simulation, c: Colonist, cell: Vector2i) -> int:
	sim.set_zone(cell, "growing")
	var j := SowJob.new(cell, sim.farming.default_crop())
	var n := 0
	while j.tick(c, sim) == Job.Status.RUNNING and n < 500:
		n += 1
	return n


func test_forester_plant_speed() -> void:
	var sim := _sim()
	var a := _spawn(sim, Vector2i(4, 4))
	var b := _spawn(sim, Vector2i(5, 4), "plants", "forester")
	var na := _sow_ticks(sim, a, Vector2i(4, 4))
	var nb := _sow_ticks(sim, b, Vector2i(5, 4))
	assert_lt(nb, na, "forester sows faster")
	assert_near(float(nb), float(na) / 1.25, 1.5, "about 25% faster")


func test_farmer_harvest_yield() -> void:
	var sim := _sim()
	for x in 2:
		sim.set_zone(Vector2i(4 + x, 4), "growing")
	var a := _spawn(sim, Vector2i(2, 2))
	var b := _spawn(sim, Vector2i(2, 3), "plants", "farmer")
	var crop := sim.farming.default_crop()
	assert_true(sim.farming.sow(Vector2i(4, 4), crop, a))
	assert_true(sim.farming.sow(Vector2i(5, 4), crop, b))
	sim.farming.plant_at(Vector2i(4, 4)).growth = 99999
	sim.farming.plant_at(Vector2i(5, 4)).growth = 99999
	var base := sim.farming.harvest(Vector2i(4, 4), a)
	assert_eq(sim.farming.harvest(Vector2i(5, 4), b), int(base * 1.25), "farmer +25% yield")


func _quality_hits(branch: String) -> int:
	var sim := _sim(21)
	var c := _spawn(sim, Vector2i(5, 5), "crafting" if branch != "" else "", branch)
	var n := 0
	for i in 300:
		if sim.quality.roll("machine_parts", c, "workbench") != "":
			n += 1
	return n


func test_smith_craft_quality() -> void:
	assert_gt(_quality_hits("smith"), _quality_hits(""), "smith rolls non-normal quality more often")


func _spared_batches(branch: String) -> int:
	var spared := 0
	for s in range(1, 61):
		var sim := _sim(s)
		var c := _spawn(sim, Vector2i(9, 5), "crafting" if branch != "" else "", branch)
		var b := sim.buildings.place("refinery", Vector2i(9, 5), false)
		sim.ledger.record_produced("essence_ore", 40, "test")
		b.input["essence_ore"] = 40
		sim.buildings.work(b, int(b.recipe["work_ticks"]), c)
		if int(b.input["essence_ore"]) == 31:
			spared += 1
	return spared


func test_tinkerer_craft_input() -> void:
	assert_eq(_spared_batches(""), 0, "no savings without the branch")
	assert_gt(_spared_batches("tinkerer"), 0, "tinkerer spares an input unit now and then")


func _mine(sim: Simulation, c: Colonist, cell: Vector2i) -> int:
	sim.map.set_tile(cell, MapGrid.Tile.DEPOSIT, 100)
	var j := MineJob.new(cell)
	var n := 0
	while j.tick(c, sim) == Job.Status.RUNNING and n < 500:
		n += 1
	return n


func test_prospector_ore_yield() -> void:
	var sim := _sim()
	var a := _spawn(sim, Vector2i(5, 5))
	var p := _spawn(sim, Vector2i(10, 10), "mining", "prospector")
	var before := sim.ledger.get_count("mining:essence_ore")
	_mine(sim, a, Vector2i(6, 5))
	var base := sim.ledger.get_count("mining:essence_ore") - before
	before += base
	var got := 0
	for i in 4:  # carried remainder: 4 digs of 5 * 1.25
		_mine(sim, p, Vector2i(11, 10 + i))
		got = sim.ledger.get_count("mining:essence_ore") - before
	assert_eq(got, int(base * 4 * 1.25), "prospector +25% ore over 4 digs")


func test_digger_mining_speed() -> void:
	var sim := _sim()
	var a := _spawn(sim, Vector2i(5, 5))
	var d := _spawn(sim, Vector2i(10, 10), "mining", "digger")
	var base := _mine(sim, a, Vector2i(6, 5))
	var fast := _mine(sim, d, Vector2i(11, 10))
	assert_lt(fast, base, "digger mines faster")
	assert_near(float(fast), float(base) / 1.25, 1.5, "about 25% faster")


func test_every_branch_effect_has_a_test_stat() -> void:
	# Guards new data: any effect key in skills.json must be one the sim reads somewhere.
	var known := ["hit_chance", "crit_chance", "burst_shots", "melee_damage", "unarmed_damage", "plant_speed", "harvest_yield",
		"craft_quality", "craft_input", "ore_yield", "mining_speed"]
	var sim := _sim()
	var bs: Dictionary = sim.defs.skills["branches"]
	for skill: String in bs:
		for b: String in bs[skill]:
			for k: String in bs[skill][b]["effects"]:
				assert_true(known.has(k), "unconsumed branch stat " + k)
