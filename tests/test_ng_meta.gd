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
	assert_eq(int(m.ng["carry_debt"]), roundi(1001 * float(m.ng_cfg()["debt_carry_frac"])))
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
	assert_eq(int(oa["opts"]["carry_debt"]), roundi(1001 * float(MetaState.new().ng_cfg()["debt_carry_frac"])))
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
	assert_eq(_debt_total(sim) - _debt_total(plain), roundi(1001 * float(MetaState.new().ng_cfg()["debt_carry_frac"])))
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


# region F4b
func _ending_summary(ending: String) -> Dictionary:
	var s := _summary()
	s["ending"] = ending
	s["credits"] = 95
	return s


func test_submit_new_names_no_debt() -> void:
	var m := MetaState.new()
	m.finish_sentence(_ending_summary("submit"))
	assert_eq(int(m.ng["carry_debt"]), 0)
	assert_ne(m.ng["dossier"]["name"], "B")  # renamed, skills kept
	assert_eq(int(m.ng["dossier"]["skills"]["mining"]), 6)
	assert_eq(int(m.ng["credits"]), 0)
	var m2 := MetaState.new()
	m2.finish_sentence(_ending_summary("submit"))
	assert_eq(m2.ng["dossier"]["name"], m.ng["dossier"]["name"])  # deterministic
	var o: Dictionary = m.make_ng_opts()["opts"]
	assert_false(o.has("carry_debt"))
	assert_eq(o["veteran"]["name"], m.ng["dossier"]["name"])


func test_escape_credits_ten_percent() -> void:
	var m := MetaState.new()
	m.finish_sentence(_ending_summary("escape"))
	assert_eq(int(m.ng["credits"]), 9)
	assert_eq(m.ng["dossier"]["name"], "B")
	assert_true(int(m.ng["carry_debt"]) > 0)
	assert_eq(int(m.make_ng_opts()["opts"]["start_credits"]), 9)
	var d: Dictionary = JSON.parse_string(JSON.stringify(m.to_dict()))
	var m2 := MetaState.new()
	m2.load_dict(d)
	assert_eq(int(m2.ng["credits"]), 9)


func test_fight_no_carry_and_legacy_double() -> void:
	var m := MetaState.new()
	m.finish_sentence(_ending_summary("fight"))
	assert_eq(int(m.ng["carry_debt"]), 0)
	assert_true((m.ng["dossier"] as Dictionary).is_empty())
	assert_true((m.ng["techs"] as Array).is_empty())
	assert_eq(int(m.ng["credits"]), 0)
	var sim := make_sim(7, true, 24, 24, peaceful_defs())
	sim.tick = sim.ticks_per_day * 3
	var base := int(Legacy.summarize(sim, "x")["legacy"])
	assert_eq(Legacy.ending_legacy_mult(sim), 1.0)
	sim.endings.mark_won("fight")
	assert_eq(Legacy.won_ending(sim), "fight")
	assert_eq(Legacy.ending_legacy_mult(sim), 2.0)
	assert_eq(int(Legacy.summarize(sim, "x")["legacy"]), base * 2)


func test_legacy_reads_manifest() -> void:
	var sim := make_sim(7, true, 24, 24, peaceful_defs())
	assert_eq(Legacy.summarize(sim, "x")["freed"], 0)
	sim.shuttle.freed = 3
	sim.shuttle.stayed = 2
	var s := Legacy.summarize(sim, "x")
	assert_eq(s["freed"], 3)
	assert_eq(s["stayed"], 2)
	assert_eq(Legacy.ng_snapshot(sim, "shuttle")["ending"], "")
# endregion
