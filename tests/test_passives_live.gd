extends TestCase
## Passives v2 live system (sim/perks/passive_system.gd). Flag off: inert. Flag on: earning,
## allocate / undo / respec through Simulation commands, save round-trip, keystone cap.


func _defs(on := true) -> Defs:
	var d := peaceful_defs()
	d.balance["passives_v2_enabled"] = on
	if on:
		d.passives_v2 = PassiveTreeV2.load_default()
	return d


func _game(on := true, seed_value := 5, opts := {}) -> Simulation:
	var sim := Simulation.new(seed_value, make_bus(), _defs(on), opts)
	sim.start_new_game()
	_sims.append(sim)
	_cur = sim
	return sim


func _stock(sim: Simulation, n: int) -> void:
	var cell := Vector2i(2, 2)
	sim.set_zone(cell, "stockpile")
	sim.ledger.record_produced("refined_essence", n, "test")
	sim.items.drop(cell, "refined_essence", n)


## First passive of `tier` the inmate could take with unlimited marks and maxed skills.
func _first(sim: Simulation, c: Colonist, tier: String, skip: Array = []) -> String:
	for id in sim.passives.tree.ids():
		if sim.passives.tree.tier_of(id) == tier and not skip.has(id) and sim.passives.can_allocate(c, id) in ["", "no_marks"]:
			return id
	return ""


func _max_skills(c: Colonist) -> void:
	_sim_of(c).passives.state_of(c)  # state first, so the jump to L10 is not credited as old levels
	for s: String in c.skills.levels:
		c.skills.levels[s] = 10


var _cur: Simulation


func _sim_of(_c: Colonist) -> Simulation:
	return _cur


func test_flag_off_is_inert() -> void:
	var sim := _game(false)
	var c: Colonist = sim.colonists.list[0]
	assert_true(sim.defs.passives_v2.is_empty(), "Defs must not load passives while off")
	assert_false(sim.passives.enabled())
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_eq(sim.passives.mod(c, "mining_speed"), 0.0)
	assert_false(sim.passives.rule(c, "no_armor"))
	assert_true(sim.passives.state_of(c) == null)
	assert_true(c.passives == null, "no state is created while off")
	assert_eq(sim.passives.can_allocate(c, "p_x"), "off")
	assert_false(sim.allocate_passive(c.id, "p_x"))
	assert_eq(sim.grant_passive_marks(c.id, 5), 0)
	assert_true(sim.passives.hash_parts().is_empty() and sim.passives.state_parts().is_empty())
	assert_false(sim.passives.has_state())


func test_milestones_and_baseline() -> void:
	var sim := _game()
	var c: Colonist = sim.colonists.list[0]
	var sk: String = c.skills.levels.keys()[0]
	c.skills.levels[sk] = 6  # a veteran: joined at L6 -> milestones <= 6 count as credited
	c.skills.mark_joined()
	sim.passives.state_of(c)
	assert_eq(c.passives.marks_earned, 0 + _others_credit(c, sk), "veteran earns no mark for old levels")
	var before := c.passives.marks_earned
	sim.bus.skill_leveled.emit(c.id, sk, 7)
	assert_eq(c.passives.marks_earned, before, "L7 is no milestone")
	c.skills.levels[sk] = 10
	sim.bus.skill_leveled.emit(c.id, sk, 10)
	assert_eq(c.passives.marks_earned, before + 3, "L10 milestone = 3 marks")
	sim.bus.skill_leveled.emit(c.id, sk, 10)
	assert_eq(c.passives.marks_earned, before + 3, "credited once")


func _others_credit(c: Colonist, _skill: String) -> int:
	# other skills may start at L3+ at creation: baseline = join level, so nothing is credited
	return 0


func test_deeds_and_counters() -> void:
	var sim := _game()
	var c: Colonist = sim.colonists.list[0]
	var m0 := sim.passives.marks_free(c)
	var seen: Array = []
	sim.bus.passive_deed.connect(func(_i: int, d: String) -> void: seen.append(d))
	sim.colonists.add_kill(c, "crawler")
	assert_eq(sim.passives.marks_free(c), m0 + 1, "First Blood = 1 mark")
	assert_true(seen.has("d_first_blood"))
	sim.colonists.add_kill(c, "crawler")
	assert_eq(sim.passives.marks_free(c), m0 + 1, "no repeat")
	sim.bus.colonist_rescued.emit(0, c.id)
	assert_eq(sim.passives.marks_free(c), m0 + 2, "rescue deed")
	for i in 10:
		sim.bus.colonist_tended.emit(0, c.id, 1)
	assert_eq(sim.passives.marks_free(c), m0 + 3, "ten tends")
	# quiet days: a break resets the counter
	for i in 5:
		sim.bus.day_started.emit(i + 1)
	assert_eq(int(c.passives.counters["quiet_days"]), 5)
	sim.bus.mood_break_started.emit(c.id, "wander")
	assert_eq(int(c.passives.counters["quiet_days"]), 0)
	for i in 30:
		sim.bus.day_started.emit(i + 10)
	assert_true(c.passives.deeds.has("d_thirty_quiet"))


func test_debt_credit_clears_and_awards() -> void:
	var sim := _game()
	var c: Colonist = sim.colonists.list[0]
	sim.run_ticks(5)  # debt state is created on the first tick
	var st: DebtState = sim.debt.state_of(c)
	var m0 := sim.passives.marks_free(c)
	assert_true(sim.debt.credit(c, st.remaining()), "credit books the whole debt without items")
	assert_eq(st.remaining(), 0)
	assert_true(c.passives.deeds.has("d_debt_cleared"), "Paid in Full")
	assert_true(c.passives.deeds.has("d_first_installment"))
	assert_gt(sim.passives.marks_free(c), m0 + 3)
	assert_false(sim.debt.credit(c, 5), "nothing left to credit")


func test_allocate_undo_through_commands() -> void:
	var sim := _game()
	var c: Colonist = sim.colonists.list[0]
	_max_skills(c)
	sim.passives.state_of(c)
	var id := _first(sim, c, "minor")
	assert_ne(id, "", "some minor is takeable")
	var hash0 := SaveGame.state_hash(sim)
	assert_false(sim.allocate_passive(c.id, id), "no marks yet")
	assert_eq(sim.passives.can_allocate(c, id), "no_marks")
	assert_eq(SaveGame.state_hash(sim), hash0, "refused allocate changes nothing")
	assert_false(sim.allocate_passive(c.id, "p_nonexistent"))
	assert_eq(sim.passives.can_allocate(c, "p_nonexistent"), "unknown")
	var free0 := sim.passives.marks_free(c)
	sim.grant_passive_marks(c.id, 5, "test")
	assert_eq(sim.passives.marks_free(c), free0 + 5)
	assert_true(sim.allocate_passive(c.id, id))
	assert_eq(sim.passives.can_allocate(c, id), "allocated")
	assert_eq(sim.passives.marks_free(c), free0 + 5 - int(sim.passives.tree.def_of(id)["cost"]))
	var stat: String = (sim.passives.tree.def_of(id)["effects"] as Dictionary).keys()[0]
	assert_ne(sim.passives.mod(c, stat), 0.0, "effect is live")
	assert_true(sim.undo_passive(c.id, id), "undo inside the grace window")
	assert_eq(sim.passives.marks_free(c), free0 + 5, "marks refunded")
	assert_eq(sim.passives.mod(c, stat), 0.0)
	assert_true(sim.allocate_passive(c.id, id))
	sim.tick += 2000  # grace is 1800 ticks
	assert_false(sim.undo_passive(c.id, id))
	assert_eq(sim.passives.can_undo(c, id), "grace")
	assert_true(sim.passives.state_of(c).allocated.has(id))


func test_respec_costs_essence_and_locks() -> void:
	var sim := _game(true, 5)
	_stock(sim, 30)
	var c: Colonist = sim.colonists.list[0]
	_max_skills(c)
	sim.grant_passive_marks(c.id, 6)
	var id := _first(sim, c, "minor")
	assert_true(sim.allocate_passive(c.id, id))
	var cost := sim.passives.respec_cost(c)
	assert_eq(int(cost["count"]), int(sim.passives.tree.def_of(id)["cost"]))
	var stock0 := sim.items.count_stored("refined_essence")
	assert_gt(stock0, 0.0, "crate gives essence")
	assert_true(sim.respec_passives(c.id))
	assert_eq(sim.items.count_stored("refined_essence"), stock0 - int(cost["count"]))
	assert_true(c.passives.allocated.is_empty())
	assert_eq(sim.passives.marks_free(c), c.passives.marks_earned, "all marks back")
	assert_eq(sim.passives.can_allocate(c, id), "locked", "3-day retraining lockout")
	assert_false(sim.respec_passives(c.id), "nothing to forget")
	sim.tick += 3 * sim.ticks_per_day + 1
	assert_eq(sim.passives.can_allocate(c, id), "")
	# without essence the respec is refused and nothing changes
	var sim2 := _game(true, 6)
	var c2: Colonist = sim2.colonists.list[0]
	_max_skills(c2)
	sim2.grant_passive_marks(c2.id, 6)
	var id2 := _first(sim2, c2, "minor")
	sim2.allocate_passive(c2.id, id2)
	for it in sim2.items.stacks.keys():
		if sim2.items.stacks[it]["item"] == "refined_essence":
			sim2.items.stacks.erase(it)
	sim2.items._stored_valid = false
	assert_eq(sim2.passives.can_respec(c2), "no_essence")
	assert_false(sim2.respec_passives(c2.id))
	assert_true(c2.passives.allocated.has(id2))


func test_keystone_cap_and_exclusion() -> void:
	var sim := _game()
	var c: Colonist = sim.colonists.list[0]
	_max_skills(c)
	var st := sim.passives.state_of(c)
	st.marks_earned = 200
	var tree := sim.passives.tree
	var taken: Array[String] = []
	var guard := 0
	# allocate everything allocatable (greedy, data order, repeated for requires) until 2 keystones
	while guard < 6:
		guard += 1
		for id in tree.ids():
			var r := sim.passives.can_allocate(c, id)
			if r == "" and tree.tier_of(id) != "keystone":
				assert_true(sim.allocate_passive(c.id, id))
	for id in tree.ids():
		if tree.tier_of(id) == "keystone" and sim.passives.can_allocate(c, id) == "":
			assert_true(sim.allocate_passive(c.id, id))
			taken.append(id)
			if taken.size() == 2:
				break
	assert_eq(taken.size(), 2, "two keystones reachable with 200 marks")
	assert_eq(tree.keystones_of(st).size(), 2)
	for id in tree.ids():
		if tree.tier_of(id) == "keystone" and not st.allocated.has(id):
			var r := sim.passives.can_allocate(c, id)
			assert_true(r in ["keystone_limit", "excluded", "requires", "gate_skill", "gate_deed"], id + " -> " + r)
			if r == "keystone_limit":
				assert_false(sim.allocate_passive(c.id, id))
				return


func test_keystone_no_armor_unequips() -> void:
	var sim := _game()
	var c: Colonist = sim.colonists.list[0]
	_max_skills(c)
	var st := sim.passives.state_of(c)
	st.marks_earned = 200
	var ks := ""
	for id in sim.passives.tree.ids():
		if sim.passives.tree.rules_of(id).has("no_armor"):
			ks = id
	assert_ne(ks, "", "a keystone carries no_armor")
	# give the inmate a worn non-weapon piece (direct state: gear shop is not under test)
	var slot := ""
	for s: String in sim.defs.equipment["slots"]:
		if s != "weapon":
			slot = s
			break
	sim.equipment.equipped[c.id] = {slot: 0}
	# take the whole path to the keystone
	var guard := 0
	while guard < 8 and not st.allocated.has(ks):
		guard += 1
		for id in sim.passives.tree.ids():
			if id != ks and sim.passives.tree.tier_of(id) != "keystone" and sim.passives.can_allocate(c, id) == "":
				var d: Dictionary = sim.passives.tree.def_of(id)
				if str(d["detail"]) == str(sim.passives.tree.def_of(ks)["detail"]).split("+")[0]:
					sim.allocate_passive(c.id, id)
		if sim.passives.can_allocate(c, ks) == "":
			sim.allocate_passive(c.id, ks)
	if st.allocated.has(ks):
		assert_true(sim.passives.rule(c, "no_armor"))
		assert_false((sim.equipment.equipped.get(c.id, {}) as Dictionary).has(slot), "worn piece unequipped")


func test_save_round_trip_keeps_marks_and_allocations() -> void:
	var d := _defs()
	var sim := Simulation.new(5, make_bus(), d)
	sim.start_new_game()
	_sims.append(sim)
	var c: Colonist = sim.colonists.list[0]
	sim.run_ticks(sim.ticks_per_day * 2)
	sim.grant_passive_marks(c.id, 6, "test")
	var id := _first(sim, c, "minor")
	assert_ne(id, "")
	assert_true(sim.allocate_passive(c.id, id))
	sim.run_ticks(40)
	var text := SaveGame.to_json(sim)
	var res := SaveGame.load_json(text, make_bus(), _defs())
	assert_true(res["ok"], str(res.get("error", "")))
	var sim2: Simulation = res["sim"]
	_sims.append(sim2)
	var c2 := sim2.colonists.get_by_id(c.id)
	assert_eq(c2.passives.allocated, c.passives.allocated)
	assert_eq(c2.passives.marks_earned, c.passives.marks_earned)
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))
	assert_eq(sim2.passives.state_parts(), sim.passives.state_parts())
	# to_dict / from_dict is lossless on its own too
	var st2 := PassiveTreeV2.State.from_dict(c.passives.to_dict())
	assert_eq(sim.passives.tree.state_hash(st2), sim.passives.tree.state_hash(c.passives))


func test_dossier_carry() -> void:
	var sim := _game()
	var c: Colonist = sim.colonists.list[0]
	sim.grant_passive_marks(c.id, 10)
	var id := _first(sim, c, "minor")
	_max_skills(c)
	sim.allocate_passive(c.id, id)
	var dos := sim.passives.dossier_of(c)
	assert_true(dos.has("marks") and dos.has("known_for"))
	var sim2 := _game(true, 7)
	var c2: Colonist = sim2.colonists.list[0]
	var m := sim2.passives.marks_free(c2)
	sim2.passives.apply_dossier(c2, {"marks": 3, "known_for": []})
	assert_eq(sim2.passives.marks_free(c2), m + 3)


## Marks earned by a bot-run colony stay inside the earning.md budget (day 10 ~4, day 25 ~9-10).
func test_earning_budget_three_seeds() -> void:
	var FB := preload("res://tools/factory_bot.gd")
	var base := Defs.get_default()
	var was: Variant = base.balance.get("passives_v2_enabled", false)
	base.balance["passives_v2_enabled"] = true
	base.passives_v2 = PassiveTreeV2.load_default()
	for sv in [1, 2, 3]:
		var bus := make_bus()
		var sim := Simulation.new(sv, bus, null, {"tutorial": true, "research_locked": true})
		sim.start_new_game()
		var bot: RefCounted = FB.new(sim)
		var best_at: Dictionary = {}
		for day in [10, 25]:
			while sim.tick < day * sim.ticks_per_day and sim.game_over_reason == "":
				bot.act()
				sim.run_ticks(FB.Bot.STEP_TICKS)
				bot.after()
			var best := 0
			for c in sim.colonists.list:
				if c.alive and c.passives != null:
					best = maxi(best, c.passives.marks_earned)
			best_at[day] = best
		sim.dispose()
		if sim.game_over_reason != "":
			continue
		assert_true(int(best_at[10]) >= 1 and int(best_at[10]) <= 6, "seed %d day 10 marks %s" % [sv, str(best_at)])
		assert_true(int(best_at[25]) >= 5 and int(best_at[25]) <= 12, "seed %d day 25 marks %s" % [sv, str(best_at)])
	base.balance["passives_v2_enabled"] = was
	base.passives_v2 = {}
