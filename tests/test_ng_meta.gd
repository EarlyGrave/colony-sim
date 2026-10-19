extends TestCase
## Next Sentence (NG+) meta core.


func _summary(seed_value := 7) -> Dictionary:
	return {"seed": seed_value, "days": 30, "result": "shuttle", "preset": "standard_term", "debt_left": 1001,
		"debt_paid": 300,
		"colonists": [
			{"id": 3, "name": "C", "skills": {"mining": 5, "crafting": 5}, "perks": []},
			{"id": 2, "name": "B", "skills": {"mining": 6, "crafting": 4}, "perks": ["miner_pace"]},
			{"id": 4, "name": "D", "skills": {"mining": 1}, "perks": []}],
		"techs": ["hand_tools", "crude_refining", "fortification", "nope"]}


func test_round_trip_and_v1_migration() -> void:
	var m := MetaState.new()
	m.finish_sentence(_summary())
	var d: Dictionary = JSON.parse_string(JSON.stringify(m.to_dict()))
	assert_eq(int(d["version"]), 2)
	var m2 := MetaState.new()
	m2.load_dict(d)
	assert_eq(JSON.stringify(m2.to_dict()), JSON.stringify(m.to_dict()))
	var m3 := MetaState.new()
	m3.load_dict({"version": 1, "balance": 4, "runs": 2})
	assert_eq(int(m3.ng["sentence"]), 1)
	assert_eq(m3.balance, 4)
	assert_false(m3.has_ng_carry())
	var m4 := MetaState.new()
	m4.load_dict({"version": 99, "balance": 4, "ng": 5})
	assert_eq(m4.balance, 0)
	m4.load_dict({"version": 2, "owned": 3, "ng": "junk"})
	assert_eq(int(m4.ng["sentence"]), 1)


func test_finish_sentence_values() -> void:
	var m := MetaState.new()
	m.finish_sentence(_summary())
	assert_eq(int(m.ng["carry_debt"]), 501)  # round(1001 * 0.5)
	assert_eq(int(m.ng["sentence"]), 2)
	assert_eq(m.ng["dossier"]["name"], "B")  # sum 10 ties with C: lowest id wins
	assert_eq(m.ng["dossier"]["perk_id"], "miner_pace")
	var techs: Array = m.ng["techs"]
	assert_true(techs.size() <= 3 and techs.size() > 0)
	for t: String in techs:
		assert_true(m.defs.research.has(t))
	for i in 25:
		m.finish_sentence(_summary(i))
	assert_eq((m.ng["history"] as Array).size(), 20)


func test_ng_opts_deterministic_and_preset_step() -> void:
	var a := MetaState.new()
	a.finish_sentence(_summary())
	var b := MetaState.new()
	b.finish_sentence(_summary())
	var oa := a.make_ng_opts()
	assert_eq(JSON.stringify(oa), JSON.stringify(b.make_ng_opts()))
	assert_eq(JSON.stringify(oa), JSON.stringify(a.make_ng_opts()))
	assert_eq(int(oa["seed"]), (7 * 1103515245 + 2 * 12345 + 1) & 0x7fffffff)
	assert_eq(a.ng_next_preset(), "hard_time")
	assert_eq(int(oa["opts"]["carry_debt"]), 501)
	assert_eq(oa["opts"]["veteran"]["name"], "B")
	assert_eq(a.preset, "standard_term")  # player's pick untouched
	var s2 := _summary(9)
	s2["preset"] = "hard_time"
	a.finish_sentence(s2)
	var w1 := float(a.make_ng_opts()["opts"]["wave_mult"])
	assert_true(w1 > 1.15)
	for i in 100:
		a.finish_sentence(s2)
	assert_true(float(a.make_ng_opts()["opts"]["wave_mult"]) <= 3.0)


func _debt_total(sim: Simulation) -> int:
	var t := 0
	for id: int in sim.debt.states:
		t += (sim.debt.states[id] as DebtState).total
	return t


func test_start_with_ng_opts() -> void:
	var m := MetaState.new()
	m.finish_sentence(_summary())
	var o: Dictionary = m.make_ng_opts()["opts"]
	var base: Dictionary = o.duplicate()
	base.erase("carry_debt")
	var plain := Simulation.new(5, make_bus(), peaceful_defs(), base)
	plain.start_new_game()
	var sim := Simulation.new(5, make_bus(), peaceful_defs(), o)
	sim.start_new_game()
	plain.run_ticks(1)  # plain inmates get their debt on the first tick
	assert_eq(_debt_total(sim) - _debt_total(plain), 501)
	var vet: Colonist = sim.colonists.list[0]
	assert_eq(vet.display_name, "B")
	assert_true(sim.perks.has(vet, "miner_pace"))
	for t: String in o["start_techs"]:
		assert_true(sim.research.is_done(t))
	var again := Simulation.new(5, make_bus(), peaceful_defs(), o)
	again.start_new_game()
	assert_eq(SaveGame.state_hash(sim), SaveGame.state_hash(again))


func test_empty_opts_unchanged() -> void:
	var a := Simulation.new(5, make_bus(), peaceful_defs(), {})
	a.start_new_game()
	var b := Simulation.new(5, make_bus(), peaceful_defs(), {"sentence": 1})
	b.start_new_game()
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b))


func test_store_atomic_and_corrupt() -> void:
	var path := OS.get_temp_dir().path_join("ng_meta_test_%d.json" % Time.get_ticks_usec())
	var m := MetaState.new()
	m.finish_sentence(_summary())
	assert_true(MetaStore.save_state(m, path))
	assert_false(FileAccess.file_exists(path + ".tmp"))
	assert_eq(int(MetaStore.load_state(path).ng["sentence"]), 2)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_eq(int(MetaStore.load_state(path).ng["sentence"]), 1)
	DirAccess.remove_absolute(path)
