extends TestCase
## Item quality: roll distribution, perks, masterwork flag, conservation, save/load.


func _sim(seed_value := 7) -> Simulation:
	var sim := make_sim(seed_value, false, 24, 20, peaceful_defs())
	sim.colonists.spawn(Vector2i(2, 2))
	for y in 2:
		for x in 3:
			sim.set_zone(Vector2i(2 + x, 10 + y), "stockpile")
	sim.ledger.record_produced("essence_ore", 60, "test")
	sim.items.drop(Vector2i(2, 10), "essence_ore", 60)
	sim.ledger.record_produced("refined_essence", 30, "test")
	sim.items.drop(Vector2i(3, 10), "refined_essence", 30)
	return sim


func _hist(sim: Simulation, c: Colonist, n: int) -> Dictionary:
	var h := {}
	for i in n:
		var q := sim.quality.roll("machine_parts", c, "workbench")
		h[q] = int(h.get(q, 0)) + 1
	return h


func _score(h: Dictionary) -> float:
	var ids := {"poor": 0, "": 1, "good": 2, "excellent": 3, "masterwork": 4}
	var s := 0.0
	for q: String in h:
		s += float(ids[q]) * float(h[q])
	return s


func _craft_perk(sim: Simulation) -> String:
	for id: String in sim.perks.perks_of_skill("crafting"):
		if float(sim.perks.perk_def(id).get("effects", {}).get("craft_quality", 0.0)) >= 0.15:
			return id
	return ""


func test_untracked_is_normal() -> void:
	var sim := _sim()
	assert_eq(sim.quality.roll("refined_essence", sim.colonists.list[0], "workbench"), "")


func test_distribution_deterministic_by_seed() -> void:
	var s1 := _sim(5)
	var s2 := _sim(5)
	var h1 := _hist(s1, s1.colonists.list[0], 200)
	assert_eq(h1, _hist(s2, s2.colonists.list[0], 200))
	assert_gt(h1.size(), 1.0, "several quality levels occur")


func test_skill_and_perk_shift() -> void:
	var sim := _sim()
	var c := sim.colonists.list[0]
	c.skills.levels["crafting"] = 0
	var base := _score(_hist(sim, c, 400))
	c.skills.levels["crafting"] = 10
	var skilled := _score(_hist(sim, c, 400))
	assert_gt(skilled, base, "skill raises quality")
	var perk := _craft_perk(sim)
	assert_ne(perk, "", "a craft_quality perk exists")
	sim.perks.state_of(c).learned.append(perk)
	var perked := _score(_hist(sim, c, 400))
	assert_gt(perked, skilled, "perk raises quality")


func test_masterwork_flag() -> void:
	var sim := _sim()
	var c := sim.colonists.list[0]
	sim.perks.state_of(c).add_buff("masterwork", {}, -1)
	assert_eq(sim.quality.roll("machine_parts", c, "workbench"), "masterwork")
	assert_false(sim.perks.has_flag(c, "masterwork"), "consumed")
	assert_gt(sim.quality.value_of("machine_parts", 1, "masterwork"), sim.quality.value_of("machine_parts", 1, ""))


func _run_bill(sim: Simulation) -> void:
	var b := sim.buildings.place("workbench", Vector2i(10, 5), false)
	sim.add_bill(b.id, "machine_parts", "count", 6)
	sim.run_ticks(4000)


func test_end_to_end_conserved() -> void:
	var sim := _sim()
	_run_bill(sim)
	assert_eq(sim.items.count_world("machine_parts"), 6)
	assert_eq(sim.ledger.balance_of("machine_parts"), 6)
	assert_gt(sim.items.count_stored("machine_parts"), 0.0)


func test_state_hash_covers_quality_and_is_reproducible() -> void:
	## Save/load is command-log replay (see SaveGame); the hash must be stable
	## per seed and sensitive to stack quality.
	var a := _sim(9)
	var b := _sim(9)
	_run_bill(a)
	_run_bill(b)
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b))
	var cell := Vector2i(8, 8)
	a.items.drop(cell, "machine_parts", 1, "good")
	var h1 := SaveGame.state_hash(a)
	a.items.stacks[cell].erase("q")
	assert_ne(SaveGame.state_hash(a), h1)
