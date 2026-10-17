extends TestCase
## Perk stat hooks: each stat shows its effect vs baseline; flags are consumed once.
## Perks are injected as permanent buffs (ColonistPerks.add_buff, until = -1).


func _sim() -> Simulation:
	return make_sim(9, false, 24, 24, peaceful_defs())


## Spawns a colonist with all skills at 3 so baselines are comparable.
func _spawn(sim: Simulation, cell: Vector2i) -> Colonist:
	var c := sim.colonists.spawn(cell)
	for s: String in c.skills.levels:
		c.skills.levels[s] = 3
	return c


func _buff(sim: Simulation, c: Colonist, stat: String, v: float) -> void:
	sim.perks.state_of(c).add_buff("t_" + stat, {stat: v}, -1)


func _conserved(sim: Simulation) -> void:
	for item: String in sim.defs.items:
		assert_eq(sim.items.count_world(item), sim.ledger.balance_of(item), "conservation " + item)


func _steps_to(sim: Simulation, c: Colonist, target: Vector2i) -> int:
	var n := 0
	while c.move_toward(target, sim) == GridMover.Move.MOVING and n < 500:
		n += 1
	return n


func test_move_speed() -> void:
	var sim := _sim()
	var a := _spawn(sim, Vector2i(2, 2))
	var b := _spawn(sim, Vector2i(2, 2))
	_buff(sim, b, "move_speed", 1.0)
	var base := _steps_to(sim, a, Vector2i(18, 2))
	var fast := _steps_to(sim, b, Vector2i(18, 2))
	assert_lt(fast, base * 0.7, "faster walker arrives sooner")


func test_work_speed_generic() -> void:
	var sim := _sim()
	var c := _spawn(sim, Vector2i(2, 2))
	var base := sim.jobs.work_tick(c, "mining")
	_buff(sim, c, "work_speed", 0.5)
	assert_near(sim.jobs.work_tick(c, "mining"), base * 1.5, 0.001)
	assert_near(sim.jobs.work_tick(c, "hauling"), 1.5, 0.001, "also unskilled work")


func _mine_ticks(sim: Simulation, c: Colonist, cell: Vector2i) -> int:
	sim.map.set_tile(cell, MapGrid.Tile.DEPOSIT, 100)
	var j := MineJob.new(cell)
	var n := 0
	while j.tick(c, sim) == Job.Status.RUNNING and n < 500:
		n += 1
	return n


func test_mining_speed_and_ore_yield() -> void:
	var sim := _sim()
	var a := _spawn(sim, Vector2i(5, 5))
	var base := _mine_ticks(sim, a, Vector2i(6, 5))
	var b := _spawn(sim, Vector2i(10, 10))
	_buff(sim, b, "mining_speed", 1.0)
	var fast := _mine_ticks(sim, b, Vector2i(11, 10))
	assert_lt(fast, base * 0.75, "mining_speed")
	# ore_yield with carried remainder: 5 * 1.5 = 7.5 -> 7, then 8.
	var d := _spawn(sim, Vector2i(15, 15))
	_buff(sim, d, "ore_yield", 0.5)
	var before := sim.ledger.get_count("mining:essence_ore")
	_mine_ticks(sim, d, Vector2i(16, 15))
	var first := sim.ledger.get_count("mining:essence_ore") - before
	assert_eq(first, 7)
	before += first
	_mine_ticks(sim, d, Vector2i(17, 15))
	assert_eq(sim.ledger.get_count("mining:essence_ore") - before, 8)
	_conserved(sim)


func _blueprint_ready(sim: Simulation, def_id: String, cell: Vector2i) -> Blueprint:
	var bp := sim.buildings.place_blueprint(def_id, cell)
	for item: String in bp.def["cost"]:
		var n := int(bp.def["cost"][item])
		sim.ledger.record_produced(item, n, "test")
		bp.delivered[item] = n
	return bp


func test_build_speed_hp_and_cost() -> void:
	var sim := _sim()
	var a := _spawn(sim, Vector2i(5, 5))
	var bp := _blueprint_ready(sim, "refinery", Vector2i(5, 6))
	var job := BuildJob.new(bp.id)
	var base := 0
	while job.tick(a, sim) == Job.Status.RUNNING and base < 2000:
		base += 1
	var plain := sim.buildings.at(Vector2i(5, 6))
	assert_true(plain != null)
	var b := _spawn(sim, Vector2i(12, 12))
	_buff(sim, b, "build_speed", 1.0)
	_buff(sim, b, "building_hp", 0.2)
	_buff(sim, b, "build_cost", -0.5)
	var bp2 := _blueprint_ready(sim, "refinery", Vector2i(12, 13))
	var consumed_before := sim.ledger.get_count("construction:essence_ore")
	var job2 := BuildJob.new(bp2.id)
	var fast := 0
	while job2.tick(b, sim) == Job.Status.RUNNING and fast < 2000:
		fast += 1
	assert_lt(fast, base * 0.75, "build_speed")
	var built := sim.buildings.at(Vector2i(12, 13))
	assert_true(built != null)
	assert_near(built.max_hp, plain.max_hp * 1.2, 0.01, "building_hp")
	assert_near(built.hp, built.max_hp, 0.001)
	var cost := int(bp2.def["cost"].get("essence_ore", 0))
	assert_gt(cost, 1, "test needs an ore cost")
	assert_eq(sim.ledger.get_count("construction:essence_ore") - consumed_before, cost - cost / 2, "half the ore spared")
	_conserved(sim)


func _refinery(sim: Simulation) -> Building:
	var b := sim.buildings.place("refinery", Vector2i(9, 5), false)
	sim.ledger.record_produced("essence_ore", 40, "test")
	b.input["essence_ore"] = 40
	return b


func _batch(sim: Simulation, b: Building, op: Colonist) -> void:
	assert_true(sim.buildings.work(b, int(b.recipe["work_ticks"]), op))


func test_operate_speed_and_craft_speed_in_job() -> void:
	var sim := _sim()
	var a := _spawn(sim, Vector2i(9, 5))
	var b := _refinery(sim)
	var j := OperateJob.new(b.id)
	var base := 0
	while j.tick(a, sim) == Job.Status.RUNNING and base < 2000:
		base += 1
	var c := _spawn(sim, Vector2i(9, 5))
	_buff(sim, c, "operate_speed", 1.0)
	b.progress = 0
	var j2 := OperateJob.new(b.id)
	var fast := 0
	while j2.tick(c, sim) == Job.Status.RUNNING and fast < 2000:
		fast += 1
	assert_lt(fast, base * 0.7)
	# craft_speed applies to non-"operating" work (cooking etc.) only.
	var d := _spawn(sim, Vector2i(9, 5))
	_buff(sim, d, "craft_speed", 1.0)
	b.progress = 0
	var j3 := OperateJob.new(b.id)
	var same := 0
	while j3.tick(d, sim) == Job.Status.RUNNING and same < 2000:
		same += 1
	assert_eq(same, base, "craft_speed does not speed refining")


func test_waste_and_contamination_and_flag() -> void:
	var sim := _sim()
	var b := _refinery(sim)
	var a := _spawn(sim, Vector2i(9, 5))
	_batch(sim, b, a)
	var base_waste := int(b.output["waste"])
	var base_cont := sim.contamination.level
	var c := _spawn(sim, Vector2i(9, 5))
	_buff(sim, c, "waste_mult", -0.4)
	_buff(sim, c, "contamination_per_batch", -0.4)
	b.output.clear()
	var lvl := sim.contamination.level
	_batch(sim, b, c)
	assert_eq(int(b.output["waste"]), floori(base_waste * 0.6), "waste_mult")
	assert_near(sim.contamination.level - lvl, base_cont * 0.6, 0.0001, "contamination_per_batch")
	# Flag: next batch makes no waste, only once.
	var d := _spawn(sim, Vector2i(9, 5))
	sim.perks.state_of(d).add_buff("no_waste_next_batch", {}, -1)
	b.output.clear()
	_batch(sim, b, d)
	assert_false(b.output.has("waste"), "no waste")
	assert_true(b.output.has("refined_essence"))
	assert_false(sim.perks.has_flag(d, "no_waste_next_batch"), "consumed")
	_batch(sim, b, d)
	assert_eq(int(b.output["waste"]), base_waste, "flag spent once")


func test_craft_input_saves_ore_and_conserves() -> void:
	var sim := _sim()
	var b := _refinery(sim)
	var c := _spawn(sim, Vector2i(9, 5))
	_buff(sim, c, "craft_input", -1.0)  # 100% for a deterministic check
	_batch(sim, b, c)
	assert_eq(int(b.input["essence_ore"]), 40 - 10 + 1, "one unit spared")
	assert_eq(sim.ledger.get_count("recipe:essence_ore"), 9)


func test_combat_hooks() -> void:
	var sim := _sim()
	var c := _spawn(sim, Vector2i(5, 5))
	var w := sim.combat.weapon_def(c)
	var base_hit := sim.combat.hit_chance(c, w, 1.0)
	_buff(sim, c, "hit_chance", 0.1)
	assert_near(sim.combat.hit_chance(c, w, 1.0), minf(base_hit + 0.1, float(sim.defs.weapons["combat"]["hit_max"])), 0.0001)
	# attack_speed shortens the cooldown.
	var e := sim.threats._spawn("brute", Vector2i(6, 5))
	sim.tick = 100
	sim.combat.try_attack(c, e)
	var cd_base: int = c.combat.next_attack_tick - 100
	_buff(sim, c, "attack_speed", 1.0)
	sim.tick = 200
	sim.combat.try_attack(c, e)
	assert_lt(c.combat.next_attack_tick - 200, cd_base)
	# melee_damage + aimed_shot (100% hit, x1.5, consumed once).
	var f := _spawn(sim, Vector2i(5, 8))
	var e2 := sim.threats._spawn("brute", Vector2i(6, 8))
	_buff(sim, f, "melee_damage", 1.0)
	sim.perks.state_of(f).add_buff("aimed_shot", {}, -1)
	var hp0 := e2.hp
	sim.combat.try_attack(f, e2)
	assert_near(hp0 - e2.hp, float(w["damage"]) * 2.0 * 1.5, 0.001)
	assert_false(sim.perks.has_flag(f, "aimed_shot"))


func test_damage_taken_and_dodge() -> void:
	var sim := _sim()
	var a := _spawn(sim, Vector2i(5, 5))
	var b := _spawn(sim, Vector2i(8, 8))
	_buff(sim, b, "damage_taken", -0.5)
	var ia := sim.health.apply_damage(a, 10.0, "torso")
	var ib := sim.health.apply_damage(b, 10.0, "torso")
	assert_near(ib.severity, ia.severity * 0.5, 0.001)
	# dodge: a 100% dodger never gets hurt by a melee creature.
	var d := _spawn(sim, Vector2i(12, 12))
	_buff(sim, d, "dodge_chance", 1.0)
	var e := sim.threats._spawn("crawler", Vector2i(13, 12))
	e.target_kind = Enemy.Target.COLONIST
	e.target_id = d.id
	e.retarget_at = 1 << 30
	sim.run_ticks(60)
	assert_true(d.health == null or d.health.injuries.is_empty(), "all bites dodged")


func test_tend_heal_infection() -> void:
	var sim := _sim()
	var doc := _spawn(sim, Vector2i(5, 5))
	var doc2 := _spawn(sim, Vector2i(5, 6))
	var p1 := _spawn(sim, Vector2i(6, 5))
	var p2 := _spawn(sim, Vector2i(6, 6))
	_buff(sim, doc2, "tend_quality", 0.5)
	_buff(sim, doc2, "heal_speed", 1.0)
	_buff(sim, doc2, "infection_chance", -0.5)
	var i1 := sim.health.apply_damage(p1, 4.0, "torso")
	var i2 := sim.health.apply_damage(p2, 4.0, "torso")
	sim.health.tend(p1, doc)
	sim.health.tend(p2, doc2)
	assert_gt(i2.tend_quality, i1.tend_quality, "tend_quality")
	assert_near(i2.heal_bonus, 1.0, 0.0001)
	assert_near(i2.infection_bonus, -0.5, 0.0001)
	var s1 := i1.severity
	var s2 := i2.severity
	sim.health.tick()
	assert_gt(s2 - i2.severity, s1 - i1.severity, "heal_speed")


func test_farming_hooks() -> void:
	var sim := _sim()
	for x in 4:
		sim.set_zone(Vector2i(4 + x, 4), "growing")
	var a := _spawn(sim, Vector2i(2, 2))
	var b := _spawn(sim, Vector2i(2, 3))
	var crop := sim.farming.default_crop()
	_buff(sim, b, "grow_speed", 1.0)
	_buff(sim, b, "harvest_yield", 0.5)
	assert_true(sim.farming.sow(Vector2i(4, 4), crop, a))
	assert_true(sim.farming.sow(Vector2i(5, 4), crop, b))
	var pa := sim.farming.plant_at(Vector2i(4, 4))
	var pb := sim.farming.plant_at(Vector2i(5, 4))
	for i in 100:
		sim.farming.tick()
	assert_gt(pb.growth, pa.growth, "grow_speed")
	pa.growth = 99999
	pb.growth = 99999
	var base := sim.farming.harvest(Vector2i(4, 4), a)
	assert_eq(sim.farming.harvest(Vector2i(5, 4), b), int(base * 1.5), "harvest_yield")
	# double_harvest flag: next harvest x2, once.
	assert_true(sim.farming.sow(Vector2i(6, 4), crop, a))
	assert_true(sim.farming.sow(Vector2i(7, 4), crop, a))
	sim.farming.plant_at(Vector2i(6, 4)).growth = 99999
	sim.farming.plant_at(Vector2i(7, 4)).growth = 99999
	sim.perks.state_of(a).add_buff("double_harvest", {}, -1)
	assert_eq(sim.farming.harvest(Vector2i(6, 4), a), base * 2)
	assert_eq(sim.farming.harvest(Vector2i(7, 4), a), base)
	_conserved(sim)


func test_plant_speed_in_jobs() -> void:
	var sim := _sim()
	sim.set_zone(Vector2i(4, 4), "growing")
	sim.set_zone(Vector2i(5, 4), "growing")
	var a := _spawn(sim, Vector2i(4, 4))
	var b := _spawn(sim, Vector2i(5, 4))
	_buff(sim, b, "plant_speed", 1.0)
	var crop := sim.farming.default_crop()
	var ja := SowJob.new(Vector2i(4, 4), crop)
	var jb := SowJob.new(Vector2i(5, 4), crop)
	var na := 0
	while ja.tick(a, sim) == Job.Status.RUNNING and na < 500:
		na += 1
	var nb := 0
	while jb.tick(b, sim) == Job.Status.RUNNING and nb < 500:
		nb += 1
	assert_lt(nb, na)


func test_threat_attract() -> void:
	var sim := _sim()
	var a := _spawn(sim, Vector2i(5, 5))
	var base := sim.threats.raid_points(3)
	_buff(sim, a, "threat_attract", -0.5)
	assert_near(sim.threats.raid_points(3), base * 0.5, 0.001)


func test_determinism() -> void:
	var sigs: Array[String] = []
	for k in 2:
		var sim := make_sim(21, true, 24, 24, peaceful_defs())
		var c := _spawn(sim, sim.map_center())
		_buff(sim, c, "ore_yield", 0.3)
		_buff(sim, c, "move_speed", 0.4)
		_buff(sim, c, "work_speed", 0.2)
		sim.run_ticks(800)
		sigs.append("%d|%d|%s" % [sim.ledger.get_count("mining:essence_ore"), sim.items.count_world("essence_ore"), str(c.cell)])
	assert_eq(sigs[0], sigs[1])
