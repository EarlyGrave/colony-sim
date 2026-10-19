extends TestCase
## S2 Pecking Order (data/quests_s2.json) + contraband default flag. W1 conds are stubbed when not registered yet.

const Q := "s2_pecking_order"


func _stub_conds(sim: Simulation) -> void:
	for nm in ["block_standing_above", "block_standing_below"]:
		if sim.quests._conds.has(nm):
			continue
		var above: bool = nm.ends_with("above")
		sim.quests.register_cond(nm, func(v: Variant) -> bool:
			if sim.blocks == null:
				return false
			for b: String in sim.blocks.standing:
				var s: float = sim.blocks.standing_of(b)
				if (s > float(v["v"])) if above else (s < float(v["v"])):
					return true
			return false)


func _force(sim: Simulation) -> void:
	sim.blocks.standing["lifer"] = 85.0
	sim.blocks.standing["clerk"] = 20.0


func _spread(sim: Simulation) -> float:
	return sim.blocks.standing_of("lifer") - sim.blocks.standing_of("clerk")


## Runs to the offer with forced standings; returns the sim (or null if never offered).
func _offered(seed_value: int, plates := 0) -> Simulation:
	var sim := make_sim(seed_value, true, 24, 24, peaceful_defs())
	if plates > 0:
		var cell: Vector2i = sim.storyteller._free_cell_near(sim.map_center(), 3)
		sim.set_zone(cell, "stockpile")
		sim.items.add_at(cell, "plate", plates)
	_stub_conds(sim)
	for _d in 14:
		_force(sim)
		for c in sim.colonists.list:  # PW2 hunger traits starve the unfed test colony before min_day 8; keep it alive
			if c.alive:
				sim.needs.add_food(c, 100.0)
		sim.run_ticks(sim.ticks_per_day)
		if not sim.quests.pending_for(Q).is_empty():
			return sim
	return null


func test_fires_in_most_seeds() -> void:
	var n := 0
	for s in range(1, 11):
		if _offered(s) != null:
			n += 1
	assert_true(n >= 7, "S2 started in %d/10 seeds" % n)


func test_separate_shrinks_spread() -> void:
	var sim := _offered(3, 20)
	assert_true(sim != null)
	assert_true(sim.items.count_stored("plate") >= 10)
	_force(sim)
	var before := _spread(sim)
	var p := sim.quests.pending_for(Q)
	assert_true(sim.answer_quest(int(p["uid"]), "separate"))
	assert_eq(_spread(sim), before - 30.0)
	assert_true(sim.quests.flag("blocks_split"))
	assert_eq(sim.quests.state(Q), "done")


func test_separate_disabled_without_plates() -> void:
	var sim := _offered(3)
	var p := sim.quests.pending_for(Q)
	for o: Dictionary in p["options"]:
		if o["id"] == "separate":
			assert_eq(bool(o["enabled"]), sim.items.count_stored("plate") >= 10)


func test_look_away_raises_strong_and_despair_mod() -> void:
	var sim := _offered(4)
	var before := sim.blocks.standing_of("lifer")
	assert_true(sim.answer_quest(int(sim.quests.pending_for(Q)["uid"]), "look_away"))
	assert_eq(sim.blocks.standing_of("lifer"), before + 5.0)
	assert_eq(sim.quests.mod("weak_despair_mult"), 1.15)
	assert_eq(int(sim.quests._mods["weak_despair_mult"]["until"]), sim.tick + 4 * sim.ticks_per_day, "expires after 4 days")


func test_mediate_never_kills() -> void:
	for s in range(1, 7):
		var sim := _offered(s)
		if sim == null:
			continue
		var alive := sim.colonists.alive_count()
		assert_true(sim.answer_quest(int(sim.quests.pending_for(Q)["uid"]), "mediate"))
		assert_eq(sim.colonists.alive_count(), alive, "mediation loss is a mood thought only")
		assert_eq(sim.quests.state(Q), "done")


func test_replay_hash_equal() -> void:
	var hs: Array = []
	for _i in 2:
		var sim := _offered(5)
		sim.answer_quest(int(sim.quests.pending_for(Q)["uid"]), "mediate")
		sim.run_ticks(sim.ticks_per_day * 2)
		hs.append(SaveGame.state_hash(sim))
	assert_eq(hs[0], hs[1])


func test_contraband_flag_reads_json() -> void:
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/contraband.json"))
	var sim := make_sim(1, true, 24, 24, peaceful_defs())
	assert_eq(sim.contraband.is_enabled(), bool(j["enabled"]))
