extends TestCase
## F11W3: passives v2 numeric hooks + keystone rule guards. One case per rule flag, table-driven over
## PassiveTreeV2.rule_consumers(): the guard changes behaviour for a holder and not for a control inmate.
## Passives are injected straight into the inmate's PassiveTreeV2.State (no marks needed).

var _tree := PassiveTreeV2.new(PassiveTreeV2.load_default())
var _h: Colonist
var _k: Colonist


func _sim(on := true, full := false, seed_value := 9) -> Simulation:
	var d := peaceful_defs()
	d.balance["passives_v2_enabled"] = on
	var sim := make_sim(seed_value, full, 30, 30, d)
	return sim


func _spawn(sim: Simulation, cell: Vector2i) -> Colonist:
	var c := sim.colonists.spawn(cell)
	for s: String in c.skills.levels:
		c.skills.levels[s] = 3
	return c


## Sim with a holder `_h` and a control `_k` (both skills 3), states for debt created.
func _pair(full := false) -> Simulation:
	var sim := _sim(true, full)
	var base := sim.map_center() if full else Vector2i(10, 10)
	_h = _spawn(sim, base)
	_k = _spawn(sim, base + Vector2i(1, 0))
	sim.run_ticks(1)
	return sim


func _pid_rule(rule: String) -> String:
	for id in _tree.ids():
		if (_tree.def_of(id).get("effects", {}) as Dictionary).has("rule_" + rule):
			return id
	return ""


func _give(sim: Simulation, c: Colonist, pid: String) -> void:
	var st := sim.passives.state_of(c)
	if not st.allocated.has(pid):
		st.allocated.append(pid)
	st.cache.clear()


func _grant(sim: Simulation, c: Colonist, rule: String) -> void:
	var pid := _pid_rule(rule)
	assert_true(pid != "", "a passive carries rule " + rule)
	_give(sim, c, pid)


func _refinery(sim: Simulation, cell := Vector2i(14, 10)) -> Building:
	var b := sim.buildings.place("refinery", cell, false)
	sim.ledger.record_produced("essence_ore", 200, "test")
	b.input["essence_ore"] = 40
	return b


func _find(sim: Simulation, giver: String, c: Colonist) -> Job:
	return (sim.jobs.givers[giver] as WorkGiver).find(c)


func _tainted(sim: Simulation, cell: Vector2i) -> void:
	for i in 6:
		sim.mutation.add_at(cell, 5.0)


# ---- table-driven: one case per rule flag ------------------------------------------------

func test_every_rule_has_a_case_and_changes_behaviour() -> void:
	var rules: Array = _tree.rule_consumers().keys()
	assert_true(rules.size() >= 30, "rule_consumers lists >= 30 rules: %d" % rules.size())
	for rule: String in rules:
		assert_true(has_method("_r_" + rule), "case for rule " + rule)
		if has_method("_r_" + rule):
			call("_r_" + rule)


func _r_unlimited_carry() -> void:
	var sim := _pair()
	_grant(sim, _h, "unlimited_carry")
	var cap := int(sim.defs.balance["colonist"]["carry_capacity"])
	var a := Vector2i(3, 3)
	var b := Vector2i(3, 6)
	for cell in [a, b]:
		sim.ledger.record_produced("essence_ore", 40, "test")
		sim.items.add_at(cell, "essence_ore", 40)
	for pair in [[_h, a], [_k, b]]:
		var c: Colonist = pair[0]
		var j := sim.jobs._haul(HaulJob.Src.GROUND, pair[1], -1, HaulJob.Dst.CELL, Vector2i(20, 20), -1, "essence_ore", 40)
		assert_true(j._pick_up(c, sim))
	assert_eq(_h.carry_count, 40, "unlimited_carry: whole stack")
	assert_lt(_k.carry_count, 40, "control is capped")
	assert_true(_k.carry_count <= cap + 20)


func _r_no_armor() -> void:
	var sim := _pair()
	_grant(sim, _h, "no_armor")
	var gh := sim.equipment.give(_h.id, "kevlar_vest", "common", 0)
	var gk := sim.equipment.give(_k.id, "kevlar_vest", "common", 0)
	assert_false(sim.equipment.equip(_h.id, gh), "no_armor refuses armour")
	assert_true(sim.equipment.equip(_k.id, gk))
	var sh := sim.equipment.give(_h.id, "prison_shiv", "common", 0)
	assert_true(sim.equipment.equip(_h.id, sh), "weapons still fine")


func _r_mining_only() -> void:
	var sim := _pair()
	var h0 := sim.jobs.work_tick(_h, "construction")
	var k0 := sim.jobs.work_tick(_k, "construction")
	var m0 := sim.jobs.work_tick(_h, "mining")
	_grant(sim, _h, "mining_only")
	assert_near(sim.jobs.work_tick(_h, "construction") / h0, 0.4, 0.02, "mining_only x0.4 off-mining")
	assert_near(sim.jobs.work_tick(_h, "mining") / m0, 1.0, 0.02, "mining unchanged")
	assert_near(sim.jobs.work_tick(_k, "construction") / k0, 1.0, 0.02, "control unchanged")


func _r_uncapped_contamination_per_batch() -> void:
	var sim := _pair()
	_grant(sim, _h, "uncapped_contamination_per_batch")
	var per := float(sim.defs.balance["contamination"]["per_batch"])
	var deltas: Array[float] = []
	for c in [_h, _k]:
		var before := sim.contamination.level
		sim.buildings.batch_operator = c
		sim.bus.batch_refined.emit(0, "refine_essence")
		sim.buildings.batch_operator = null
		deltas.append(sim.contamination.level - before)
	assert_near(deltas[0], per * 0.4, 0.001, "-0.6 passes the -0.4 floor for the holder")
	assert_near(deltas[1], per, 0.001, "control full contamination")


func _r_refine_strike() -> void:
	var sim := _pair()
	_refinery(sim)
	_grant(sim, _h, "refine_strike")
	sim.contamination.level = 10.0
	assert_true(_find(sim, "operate", _h) != null, "below 50 % he still refines")
	sim.contamination.level = 60.0
	assert_true(_find(sim, "operate", _h) == null, "refine_strike above 50 %")
	assert_true(_find(sim, "operate", _k) != null, "control keeps refining")


func _r_no_medicine() -> void:
	var sim := _pair()
	_grant(sim, _h, "no_medicine")
	for c in [_h, _k]:
		sim.health.apply_damage(c, 10.0, "torso", "cut")
	assert_eq(sim.health.tend(_h), 0, "no_medicine: nobody can tend him")
	assert_eq(sim.health.tend(_k), 1, "control is tended")


func _r_essence_heal() -> void:
	var sim := _pair()
	_grant(sim, _h, "essence_heal")
	var sev: Array[float] = []
	for c in [_h, _k]:
		var inj := sim.health.apply_damage(c, 10.0, "legs", "bruise")
		sev.append(inj.severity)
	sim.health.tick()
	var ih: Injury = _h.health.injuries[0]
	var ik: Injury = _k.health.injuries[0]
	assert_eq(ih.severity, sev[0], "heals x0 off tainted ground")
	assert_lt(ik.severity, sev[1], "control heals")
	_tainted(sim, _h.cell)
	sim.health.tick()
	assert_lt(ih.severity, sev[0], "heals on tainted ground")


func _r_taint_immune() -> void:
	var sim := _pair()
	sim.mutation._cfg["illness_chance"] = 2.0
	_grant(sim, _h, "taint_immune")
	_tainted(sim, _h.cell)
	_tainted(sim, _k.cell)
	sim.mutation._expose_colonists(int(sim.mutation._cfg["exposure_ticks"]))
	var ill_h := _h.health != null and not _h.health.injuries.is_empty()
	var ill_k := _k.health != null and not _k.health.injuries.is_empty()
	assert_false(ill_h, "taint_immune never ill")
	assert_true(ill_k, "control falls ill")


func _r_quality_cap_common() -> void:
	var sim := _pair()
	_grant(sim, _h, "quality_cap_common")
	_h.skills.levels["crafting"] = 20
	_k.skills.levels["crafting"] = 20
	var item := str(sim.quality._cfg["tracked"][0])
	var best_k := 0
	for i in 20:
		assert_eq(sim.quality.roll(item, _h, "workbench"), "poor", "capped at the lowest tier")
		if sim.quality.roll(item, _k, "workbench") != "poor":
			best_k += 1
	assert_gt(best_k, 0, "control rolls higher tiers")


func _r_craft_only() -> void:
	var sim := _pair()
	sim.set_zone(Vector2i(2, 2), "stockpile")
	sim.ledger.record_produced("essence_ore", 5, "test")
	sim.items.drop(Vector2i(8, 10), "essence_ore", 5)
	_grant(sim, _h, "craft_only")
	assert_true(sim.jobs.assign(_k) != null, "control gets hauling")
	assert_true(sim.jobs.assign(_h) == null, "craft_only: no hauling")


func _r_no_downed() -> void:
	var sim := _pair()
	_grant(sim, _h, "no_downed")
	var big := float(sim.defs.health["parts"]["legs"]["max_hp"]) * 3.0
	sim.health.apply_damage(_k, big, "legs", "bruise")
	sim.health.apply_damage(_h, big, "legs", "bruise")
	assert_true(_k.alive and sim.health.is_downed(_k), "control is downed")
	assert_false(_h.alive, "no_downed: dies instead")


func _r_rage() -> void:
	var sim := _pair()
	_grant(sim, _h, "rage")
	for c in [_h, _k]:
		sim.mood.state_of(c).value = 20.0
	assert_near(sim.combat.rage_mult(_h), 1.3, 0.001, "mood 20 -> x1.3")
	assert_eq(sim.combat.rage_mult(_k), 1.0)
	sim.mood.state_of(_h).value = 50.0
	assert_near(sim.combat.rage_mult(_h), 1.0, 0.001, "mood 50 -> x1.0")
	sim.mood.state_of(_h).value = 80.0
	assert_near(sim.combat.rage_mult(_h), 0.75, 0.001, "mood 80 -> x0.75")


func _r_field_tend() -> void:
	var sim := _pair()
	var p1 := _spawn(sim, Vector2i(12, 10))
	var p2 := _spawn(sim, Vector2i(13, 10))
	_grant(sim, _h, "field_tend")
	var i1 := sim.health.apply_damage(p1, 10.0, "legs", "bruise")
	var i2 := sim.health.apply_damage(p2, 10.0, "legs", "bruise")
	sim.health.tend(p1, _h)
	sim.health.tend(p2, _k)
	var s1 := i1.severity
	var s2 := i2.severity
	sim.health.tick()
	assert_gt(s1 - i1.severity, (s2 - i2.severity) * 1.5, "field_tend patient heals with the bed multiplier")


func _r_no_draft() -> void:
	var sim := _pair()
	_grant(sim, _h, "no_draft")
	assert_false(sim.combat.set_drafted(_h, true), "no_draft refused")
	assert_true(sim.combat.set_drafted(_k, true))


func _r_no_sleep() -> void:
	var sim := _pair()
	_grant(sim, _h, "no_sleep")
	for c in [_h, _k]:
		sim.needs.state_of(c).rest = 0.5
		c.job = null
	sim.needs.tick()
	assert_eq(sim.needs.state_of(_h).rest, 1.0, "no_sleep pins rest")
	assert_lt(sim.needs.state_of(_k).rest, 0.5, "control tires")


func _r_night_breaks() -> void:
	var sim := _pair()
	_grant(sim, _h, "night_breaks")
	var check := int(sim.defs.mood["check_ticks"])
	var t := 0
	while t < sim.ticks_per_day and not sim.clock.is_night(t):
		t += check
	assert_true(sim.clock.is_night(t), "found a night tick")
	sim.tick = t
	sim.mood.tick()
	assert_true(sim.mood.state_of(_h).find("night_terrors") >= 0, "night_terrors for the holder")
	assert_true(sim.mood.state_of(_k).find("night_terrors") < 0, "not for the control")


func _r_no_installment() -> void:
	var sim := _pair()
	_grant(sim, _h, "no_installment")
	assert_eq(sim.traits.installment(_h, 4), 0)
	assert_gt(sim.traits.installment(_k, 4), 0)
	for c in [_h, _k]:
		var st := sim.debt.state_of(c)
		st.due_day = 0
		st.period_paid = 0
		st.total = 30
	assert_false(sim.debt.is_overdue(_h), "never overdue")
	assert_true(sim.debt.is_overdue(_k))


func _r_always_informant() -> void:
	var sim := _sim(true, true)
	for i in 8:
		sim.colonists.add(ColonistGenerator.generate(sim, sim.map_center() + Vector2i(i, -2)))
	sim.run_ticks(1)
	var other := sim.blocks.informant_id()
	var pick: Colonist = null
	for c in sim.colonists.list:
		if c.alive and c.id != other:
			pick = c
			break
	_grant(sim, pick, "always_informant")
	sim.blocks._pick_informant()
	assert_eq(sim.blocks.informant_id(), pick.id, "always_informant takes the role")
	assert_true(other != pick.id)


func _r_off_roll() -> void:
	var sim := _pair(true)
	_grant(sim, _h, "off_roll")
	var item := str(sim.defs.debt["item"])
	var z := sim.map_center() + Vector2i(4, 4)
	sim.set_zone(z, "stockpile")
	sim.ledger.record_produced(item, 20, "test")
	sim.items.drop(z, item, 20)
	assert_false(sim.debt.pay(_h, 1), "off_roll: pay refused")
	assert_true(sim.debt.pay(_k, 1), "control pays")
	for c in [_h, _k]:
		var st := sim.debt.state_of(c)
		st.total = 30
		st.paid = 0
		st.due_day = 0
		st.period_paid = int(sim.defs.debt["installment"])
	var th := sim.debt.state_of(_h).total
	sim.debt._daily(_h, sim.debt.state_of(_h))
	sim.debt._daily(_k, sim.debt.state_of(_k))
	assert_eq(sim.debt.state_of(_h).total, th, "no interest for off_roll")
	assert_gt(sim.debt.state_of(_k).total, 30, "control pays interest")
	assert_eq(sim.traits.installment(_h, 4), 0)
	sim.contraband.stash[_h.id] = 5
	sim.contraband.stash[_k.id] = 5
	sim.contraband._confiscate(0)
	assert_eq(int(sim.contraband.stash.get(_h.id, 0)), 5, "_confiscate skips his stash")
	assert_false(sim.contraband.stash.has(_k.id), "control's stash taken")


func _r_no_refinery() -> void:
	var sim := _pair()
	_refinery(sim)
	_grant(sim, _h, "no_refinery")
	assert_true(_find(sim, "operate", _h) == null, "no_refinery")
	assert_true(_find(sim, "operate", _k) != null, "control refines")


func _taint_mine(sim: Simulation, c: Colonist, ore: int) -> int:
	var target := Vector2i(8, 8)
	_tainted(sim, target)
	return MineJob.new(target)._passive_rules(c, sim, ore)


func _r_taint_mining() -> void:
	var sim := _pair()
	_grant(sim, _h, "taint_mining")
	var before := sim.contamination.level
	assert_eq(_taint_mine(sim, _h, 10), 20, "x2 ore on tainted ground")
	assert_gt(sim.contamination.level, before, "adds contamination")
	var mid := sim.contamination.level
	assert_eq(_taint_mine(sim, _k, 10), 10, "control unchanged")
	assert_eq(sim.contamination.level, mid)


func _r_essence_craft() -> void:
	var sim := _pair()
	_grant(sim, _h, "essence_craft")
	sim.set_zone(Vector2i(2, 2), "stockpile")
	var results: Array[bool] = []
	for c in [_h, _k]:
		var b := sim.buildings.place("workbench", Vector2i(10, 12) if c == _h else Vector2i(16, 12), false)
		var inp: Dictionary = sim.defs.recipes["craft_gear_vest"]["inputs"]
		for item: String in inp:
			sim.ledger.record_produced(item, int(inp[item]), "test")
			b.input[item] = int(inp[item])
		assert_gt(sim.add_bill(b.id, "craft_gear_vest", "count", 1), 0)
		sim.crafting._select(b)
		results.append(sim.buildings.work(b, int(b.recipe["work_ticks"]), c))
	assert_false(results[0], "essence_craft refused without stored essence_ore")
	assert_true(results[1], "control crafts")
	sim.ledger.record_produced("essence_ore", 2, "test")
	sim.items.add_at(Vector2i(2, 2), "essence_ore", 2)
	var lvl := sim.contamination.level
	var bh: Building = null
	for b in sim.buildings.list:
		if b.def_id == "workbench" and b.cell == Vector2i(10, 12):
			bh = b
	assert_true(sim.buildings.work(bh, int(bh.recipe["work_ticks"]), _h), "crafts once ore is stored")
	assert_eq(sim.items.count_stored("essence_ore"), 1, "consumed +1 essence_ore")
	assert_gt(sim.contamination.level, lvl, "adds 0.25 batch")


func _r_burns() -> void:
	var sim := _pair()
	_grant(sim, _h, "burns")
	var b := _refinery(sim)
	for i in 10:
		for c in [_h, _k]:
			b.input["essence_ore"] = 10
			b.output.clear()
			b.broken = false
			b.condition = 100.0
			assert_true(sim.buildings.work(b, int(b.recipe["work_ticks"]), c))
	var burned := false
	if _h.health != null:
		for i: Injury in _h.health.injuries:
			burned = burned or i.kind == "burn"
	assert_true(burned, "the 10th batch burns the holder")
	assert_true(_k.health == null or _k.health.injuries.is_empty(), "control unharmed")


func _r_double_armor() -> void:
	var sim := _pair()
	_grant(sim, _h, "double_armor")
	var gh := sim.equipment.give(_h.id, "kevlar_vest", "common", 0)
	var gk := sim.equipment.give(_k.id, "kevlar_vest", "common", 0)
	assert_true(sim.equipment.equip(_h.id, gh) and sim.equipment.equip(_k.id, gk))
	var sh := sim.equipment.total(_h.id, "armor_phys")
	var sk := sim.equipment.total(_k.id, "armor_phys")
	assert_gt(sk, 0.0)
	assert_near(sh, sk * 2.0, 0.001, "double_armor x2")


func _r_melee_only() -> void:
	var sim := _pair()
	_grant(sim, _h, "melee_only")
	var rh := sim.equipment.give(_h.id, "rifle", "common", 0)
	var rk := sim.equipment.give(_k.id, "rifle", "common", 0)
	assert_false(sim.equipment.equip(_h.id, rh), "melee_only refuses ranged")
	assert_true(sim.equipment.equip(_k.id, rk))
	var xh := _h.skills.xp_total(sim.defs, "shooting")
	var xk := _k.skills.xp_total(sim.defs, "shooting")
	sim.progression.award(_h, "shooting", 10.0, "test")
	sim.progression.award(_k, "shooting", 10.0, "test")
	assert_eq(_h.skills.xp_total(sim.defs, "shooting"), xh, "no shooting xp")
	assert_gt(_k.skills.xp_total(sim.defs, "shooting"), xk)


func _r_no_ammo() -> void:
	var sim := _pair()
	_grant(sim, _h, "no_ammo")
	for c in [_h, _k]:
		sim.ammo._pouch_init(c)
		c.combat.pouch = 0
	assert_true(sim.ammo.rifle_try_fire(_h), "no_ammo fires with an empty pouch")
	assert_eq(_h.combat.pouch, 0)
	assert_false(sim.ammo.rifle_try_fire(_k), "control is dry")


func _r_ignore_pain() -> void:
	var sim := _pair()
	_grant(sim, _h, "ignore_pain")
	for c in [_h, _k]:
		sim.health.apply_damage(c, float(sim.defs.health["parts"]["arms"]["max_hp"]) * 0.6, "arms", "bruise")
		c.hp = 1.0
	var h_ok := 0
	var k_ok := 0
	for i in 20:
		h_ok += 1 if sim.health.can_act(_h) else 0
		k_ok += 1 if sim.health.can_act(_k) else 0
	assert_eq(h_ok, 20, "ignore_pain always acts")
	assert_lt(k_ok, 20, "control loses ticks")
	assert_false(sim.combat.is_low_hp(_h))
	assert_true(sim.combat.is_low_hp(_k))
	sim.mood.tick()
	assert_true(sim.mood.state_of(_h).find("injured") < 0, "no injured thought")


func _r_medic() -> void:
	var sim := _pair()
	var p1 := _spawn(sim, Vector2i(12, 10))
	var p2 := _spawn(sim, Vector2i(13, 10))
	_grant(sim, _h, "medic")
	for p in [p1, p2]:
		sim.health.apply_damage(p, 10.0, "torso", "cut")
	p1.health.carrier_id = _h.id
	p2.health.carrier_id = _k.id
	var b1 := p1.health.blood
	var b2 := p2.health.blood
	sim.health.tick()
	assert_eq(p1.health.blood, b1, "a patient carried by a medic stops bleeding")
	assert_lt(p2.health.blood, b2, "control carrier: bleeding")


func _r_pacifist() -> void:
	var sim := _pair()
	_grant(sim, _h, "pacifist")
	assert_false(sim.combat._try_attack(_h, null), "pacifist never attacks")
	assert_false(sim.combat.set_drafted(_h, true))
	assert_true(sim.combat.set_drafted(_k, true))


func _r_block_chaplain() -> void:
	var sim := _pair(true)
	var mate := _spawn(sim, sim.map_center() + Vector2i(3, 0))
	for c in [_h, _k, mate]:
		sim.blocks.member_of[c.id] = "fresh_fish"
	sim.blocks.standing["fresh_fish"] = 50.0
	var base := sim.blocks.despair_mult(mate)
	_grant(sim, _h, "block_chaplain")
	sim.blocks._scan_chaplains()
	assert_near(sim.blocks.despair_mult(mate), base * 0.5, 0.0001, "chaplain halves the block's despair")
	sim.blocks.member_of[mate.id] = "debtors" if sim.blocks.standing.has("debtors") else "old_timers"
	if sim.blocks.standing.has(sim.blocks.member_of[mate.id]):
		assert_eq(sim.blocks.despair_mult(mate), sim.blocks.despair_mult(mate), "other blocks untouched")


func _r_despair_frozen() -> void:
	var sim := _pair(true)
	_grant(sim, _h, "despair_frozen")
	for c in [_h, _k]:
		var st := sim.debt.state_of(c)
		st.total = 30
		st.paid = 0
		st.due_day = -100
		st.period_paid = 0
		st.despair = 10.0
		sim.debt._daily(c, st)
	assert_eq(sim.debt.state_of(_h).despair, 10.0, "despair never grows")
	assert_gt(sim.debt.state_of(_k).despair, 10.0, "control despairs")


func _r_debt_in_hp() -> void:
	var sim := _pair(true)
	_grant(sim, _h, "debt_in_hp")
	for c in [_h, _k]:
		var st := sim.debt.state_of(c)
		st.total = 40
		st.paid = 0
		st.due_day = 0
		st.period_paid = 0
		st.despair = 0.0
		sim.debt._daily(c, st)
	var inst := int(sim.defs.debt["installment"])
	assert_gt(sim.debt.state_of(_h).paid, 0, "installment booked as paid")
	assert_eq(sim.debt.state_of(_k).paid, 0)
	var letting := false
	for i: Injury in _h.health.injuries:
		letting = letting or i.kind == "letting"
	assert_true(letting, "letting injury of 20 % max hp")
	assert_true(inst > 0)


func _r_ore_installment() -> void:
	var sim := _pair(true)
	_grant(sim, _h, "ore_installment")
	var sh := sim.debt.state_of(_h)
	var sk := sim.debt.state_of(_k)
	sh.total = 100
	sk.total = 100
	var j := MineJob.new(Vector2i(8, 8))
	j._passive_rules(_h, sim, 25)
	j._passive_rules(_k, sim, 25)
	assert_eq(sh.paid, 2, "25 ore -> 2 units")
	assert_eq(sk.paid, 0)
	j._passive_rules(_h, sim, 5)
	assert_eq(sh.paid, 3, "the remainder carries")


func _r_no_haul() -> void:
	var sim := _pair()
	sim.set_zone(Vector2i(2, 2), "stockpile")
	sim.ledger.record_produced("essence_ore", 5, "test")
	sim.items.drop(Vector2i(8, 10), "essence_ore", 5)
	_grant(sim, _h, "no_haul")
	assert_true(_find(sim, "haul", _k) != null, "control hauls")
	assert_true(_find(sim, "haul", _h) == null, "no_haul")


func _r_ore_skim() -> void:
	var sim := _pair(true)
	sim.defs.contraband["enabled"] = true
	sim.ledger.record_produced(str(sim.defs.contraband["item"]), 1000, "recipe")
	_grant(sim, _h, "ore_skim")
	var j := MineJob.new(Vector2i(8, 8))
	assert_eq(j._passive_rules(_h, sim, 50), 45, "10 % skimmed")
	assert_eq(int(sim.contraband.stash.get(_h.id, 0)), 5)
	assert_eq(j._passive_rules(_k, sim, 50), 50)
	assert_false(sim.contraband.stash.has(_k.id))
	assert_eq(sim.contraband.skimmed, 5, "conservation counter")


func _r_raid_first() -> void:
	var sim := _pair(true)
	sim.defs.contraband["enabled"] = true
	_grant(sim, _h, "raid_first")
	sim.contraband.stash[_h.id] = 5
	sim.contraband.stash[_k.id] = 9
	sim.contraband.skimmed = 14
	sim.contraband._confiscate(6)
	assert_false(sim.contraband.stash.has(_h.id), "his stash is emptied first")
	assert_eq(int(sim.contraband.stash.get(_k.id, 0)), 8, "others keep the rest")
	assert_eq(sim.contraband.skimmed, sim.contraband.stash_total() + sim.contraband.recovered + sim.contraband.leaked)


# ---- numeric hooks, caps, determinism ----------------------------------------------------

func test_numeric_hooks_move_stats() -> void:
	var sim := _pair()
	var w0 := sim.jobs.work_tick(_h, "construction")
	_give(sim, _h, "p_infirmary_white_nights")  # work_speed +0.5 (+ rules)
	assert_near(sim.jobs.work_tick(_h, "construction") / w0, 1.5, 0.03, "work_speed")
	var need0 := sim.needs.state_of(_k).food
	_give(sim, _k, "p_infirmary_field_surgeon")  # hunger +0.3
	sim.needs.tick()
	assert_lt(sim.needs.state_of(_k).food, need0, "hunger drains")
	var cap0 := sim.traits.carry_cap(_h, 10)
	assert_eq(sim.traits.carry_cap(_h, 10), cap0)


func test_contamination_cap_on_sum() -> void:
	var sim := _pair()
	var per := float(sim.defs.balance["contamination"]["per_batch"])
	_give(sim, _h, "p_stacks_slow_pour")
	_give(sim, _h, "p_stacks_cold_hands")  # -0.45 -> floored at -0.4
	var before := sim.contamination.level
	sim.buildings.batch_operator = _h
	sim.bus.batch_refined.emit(0, "refine_essence")
	sim.buildings.batch_operator = null
	assert_near(sim.contamination.level - before, per * 0.6, 0.001, "sum floored at -0.4")


func test_always_informant_adds_no_rng_draw() -> void:
	var states: Array = []
	for on in [false, true]:
		var sim := _sim(true, true, 21)
		for i in 8:
			sim.colonists.add(ColonistGenerator.generate(sim, sim.map_center() + Vector2i(i, -2)))
		sim.run_ticks(1)
		if on:
			_grant(sim, sim.colonists.list[3], "always_informant")
		var before := sim.rng.state
		sim.blocks._pick_informant()
		sim.blocks._scan_chaplains()
		states.append([before, sim.rng.state])
	assert_eq(states[0][1] == states[0][0], states[1][1] == states[1][0], "same rng consumption on/off")


func test_flag_off_and_no_allocation_is_inert() -> void:
	var hashes: Array = []
	for on in [false, true]:
		var sim := _sim(on, true, 33)
		sim.run_ticks(900)
		hashes.append(SaveGame.state_hash(sim))
	assert_eq(hashes[0], hashes[1], "flag on with nothing allocated == flag off")


func test_thirty_day_run_with_rules_has_no_errors() -> void:
	var sim := _sim(true, true, 7)
	var ids: Array = _tree.rule_consumers().keys()
	var rules: Array[String] = []
	for r: String in ids:
		rules.append(r)
	var i := 0
	for c in sim.colonists.list:
		_grant(sim, c, rules[(i * 5) % rules.size()])
		_grant(sim, c, rules[(i * 7 + 3) % rules.size()])
		i += 1
	sim.run_ticks(sim.ticks_per_day * 30)
	assert_true(sim.tick >= sim.ticks_per_day * 30 or sim.game_over_reason != "")
