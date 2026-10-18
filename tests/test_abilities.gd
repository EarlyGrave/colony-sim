extends TestCase
## C2 role abilities: taunt / volley / stabilise (squads are injected with Abilities.set_test_squad until C1 lands).

const STORE := Vector2i(2, 2)


func _scene(essence := 5) -> Simulation:
	var sim := make_sim(5, false, 30, 30, peaceful_defs())
	sim.set_zone(STORE, "stockpile")
	if essence > 0:
		sim.ledger.record_produced("refined_essence", essence, "test")
		sim.items.drop(STORE, "refined_essence", essence)
	return sim


## Squad 1: Bulwark `b`, plain inmate `p` (not in the squad).
func _pair(sim: Simulation) -> Array:
	var p := sim.colonists.spawn(Vector2i(8, 10))
	var b := sim.colonists.spawn(Vector2i(12, 10))
	sim.abilities.set_test_squad(1, [b.id], {b.id: "bulwark"})
	return [b, p]


func _picks_on(sim: Simulation, b: Colonist) -> int:
	var hits := 0
	sim.threats.model.refresh(true)
	for k in range(1, 6):
		for dy in [-k, k]:
			var e: Enemy = sim.threats._spawn("crawler", Vector2i(10, 10 + dy))
			var r := sim.threats.model.pick(e)
			if r.get("kind", "") == "colonist" and int(r["id"]) == b.id:
				hits += 1
	return hits


func test_taunt_pulls_picks_only_during_window() -> void:
	var sim := _scene()
	var bp := _pair(sim)
	var b: Colonist = bp[0]
	sim.mutation.add_at(bp[1].cell, float(sim.defs.weapons["abilities"]["taunt"]["contam_puff"]))  # equal pollution
	assert_true(sim.use_ability(1, "taunt"))
	assert_gt(_picks_on(sim, b), 7, "taunt: >= 80% of 10 picks on the Bulwark")
	var sim2 := _scene()
	var bp2 := _pair(sim2)
	sim2.mutation.add_at(bp2[1].cell, float(sim2.defs.weapons["abilities"]["taunt"]["contam_puff"]))
	assert_true(sim2.use_ability(1, "taunt"))
	sim2.tick += int(sim2.defs.weapons["abilities"]["taunt"]["taunt"]["ticks"])
	sim2.abilities.tick()
	assert_true(sim2.abilities.flags_of(bp2[0].id).is_empty(), "flags clear on expiry")
	assert_lt(_picks_on(sim2, bp2[0]), 5, "after the window < 50%")


func test_taunt_radius_limits_effect() -> void:
	var sim := _scene()
	var bp := _pair(sim)
	sim.use_ability(1, "taunt")
	var far: Enemy = sim.threats._spawn("crawler", Vector2i(12, 28))  # 18 cells from the Bulwark, 18.9 from p
	var m := sim.threats.model
	m.refresh(true)
	var base := m.colonist_value(bp[1])
	var i_b := -1
	for i in m._val.size():
		if m._kind[i] == 1 and m._id[i] == bp[0].id:
			i_b = i
	assert_gt(m._val[i_b], base * 3.9, "cached value carries taunt x burst")
	var d := Vector2(bp[0].cell).distance_to(Vector2(far.cell))
	assert_gt(d, 6.0)
	assert_near(m.score(i_b, far), m._val[i_b] * 1.2 / 4.0 / (1.0 + pow(d / 12.0, 2.0)), 0.001, "beyond radius the taunt part is dropped")


func test_cooldown_and_costs() -> void:
	var sim := _scene(3)
	var bp := _pair(sim)
	var b: Colonist = bp[0]
	var cfg: Dictionary = sim.defs.weapons["abilities"]["taunt"]
	var before := sim.mutation.value_at(b.cell)
	var tol := float(cfg["contam_puff"]) * 0.01
	assert_true(sim.use_ability(1, "taunt"))
	assert_eq(sim.items.count_stored("refined_essence"), 3 - int(cfg["essence_cost"]), "essence drops by exactly essence_cost")
	assert_near(sim.mutation.value_at(b.cell) - before, float(cfg["contam_puff"]), tol, "puff +-1%")
	assert_true(sim.abilities.flags_of(b.id).has("burst"), "noise burst flag")
	var t0 := sim.tick
	var cd := int(cfg["cooldown_ticks"])
	sim.tick = t0 + cd - 1
	assert_false(sim.use_ability(1, "taunt"), "rejected 1 tick early")
	assert_eq(sim.items.count_stored("refined_essence"), 2, "rejection costs nothing")
	sim.tick = t0 + cd
	assert_true(sim.use_ability(1, "taunt"), "ready exactly at cooldown_ticks")


func test_no_essence_no_squad_no_debt() -> void:
	var sim := _scene(0)
	_pair(sim)
	assert_false(sim.use_ability(1, "taunt"), "no essence in storage")
	assert_false(sim.use_ability(99, "taunt"), "no such squad")
	assert_false(sim.use_ability(1, "nonsense"))
	assert_eq(sim.abilities.cooldowns.size(), 0, "rejections leave no state")
	assert_eq(sim.abilities.state_parts(), [], "no hash contribution")


func test_volley_first_shot_is_double_and_burst_of_three() -> void:
	var sim := _scene()
	var l := sim.colonists.spawn(Vector2i(5, 5))
	l.combat.weapon = "rifle"
	sim.ammo._pouch_init(l)
	l.combat.pouch = 100000
	sim.abilities.set_test_squad(1, [l.id], {l.id: "lancer"})
	var e: Enemy = sim.threats._spawn("crawler", Vector2i(10, 5))
	e.hp = 1.0e9
	var dmg := float(sim.defs.weapons["weapons"]["rifle"]["damage"])
	assert_true(sim.use_ability(1, "volley"))
	var seen: Array[float] = []
	for i in 4:
		var h := e.hp
		l.combat.next_attack_tick = 0
		sim.combat.try_attack(l, e)
		seen.append(h - e.hp)
	assert_true(seen[0] >= dmg * 1.9, "first shot >= 1.9x (%f)" % seen[0])
	assert_true(seen[1] >= dmg * 1.9 and seen[2] >= dmg * 1.9, "three burst shots")
	assert_true(seen[3] <= dmg * 1.01, "fourth shot is normal (%f)" % seen[3])
	assert_false(sim.abilities.volley.has(l.id))


func test_stabilise_needs_a_down_inmate() -> void:
	var sim := _scene()
	var m := sim.colonists.spawn(Vector2i(8, 10))
	var d := sim.colonists.spawn(Vector2i(9, 10))
	sim.abilities.set_test_squad(1, [m.id], {m.id: "medic"})
	assert_false(sim.use_ability(1, "stabilise"), "nobody Down: rejected")
	assert_eq(sim.items.count_stored("refined_essence"), 5, "no essence spent")
	if sim.health.has_method("stabilise"):  # C4 merged
		sim.health.apply_damage(d, 1000.0)
		if sim.health.is_downed(d):
			assert_true(sim.use_ability(1, "stabilise"))


func test_deterministic_and_hash_untouched_without_use() -> void:
	var hashes: Array[int] = []
	for run in 2:
		var sim := _scene()
		_pair(sim)
		sim.use_ability(1, "taunt")
		sim.run_ticks(200)
		hashes.append(SaveGame.state_hash(sim))
	assert_eq(hashes[0], hashes[1], "same commands, same hash")
	var a := _scene()
	var b := _scene()
	a.run_ticks(50)
	b.run_ticks(50)
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b))
	assert_eq(a.abilities.state_parts(), [], "no ability use -> hash part absent")
