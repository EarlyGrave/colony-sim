extends TestCase
## Passives v2 (sim/perks/passive_tree_v2.gd): data validity, marks, allocation graph, undo,
## respec, aggregation, dossier, determinism. The module is exercised directly (flag OFF: not
## wired into the sim, see test_flag_off).

const TPD := 1800


func _tree() -> PassiveTreeV2:
	return PassiveTreeV2.new()


func _rich(tree: PassiveTreeV2, n := 40) -> PassiveTreeV2.State:
	var st := PassiveTreeV2.State.new()
	tree.earn(st, n)
	return st


func _ctx(level := 10) -> Dictionary:
	return {"skills": {"mining": level, "construction": level, "operating": level, "crafting": level,
		"shooting": level, "melee": level, "medicine": level}}


## Allocates the whole Pit detail up to the three notables (entry gate: mining).
func _pit_to_notables(tree: PassiveTreeV2, st: PassiveTreeV2.State) -> void:
	for id in ["p_pit_callouses", "p_pit_yard_shoulders", "p_pit_pick_rhythm", "p_pit_scaffold_eye", "p_pit_the_mule",
			"p_pit_ore_sense", "p_pit_salvage_habit", "p_pit_long_shift", "p_pit_quiet_pick", "p_pit_braced_walls",
			"p_pit_vein_reader"]:
		assert_true(tree.allocate(st, id, _ctx()), "allocate " + id + ": " + tree.can_allocate(st, id, _ctx()))


func test_flag_off() -> void:
	var b: Dictionary = Defs.get_default().balance
	assert_true(b.has("passives_v2_enabled"))
	assert_false(bool(b["passives_v2_enabled"]))
	assert_false("passives_v2" in Defs.get_default().get_property_list().map(func(p: Dictionary) -> String: return str(p["name"])),
		"Defs must not load passives_v2.json while the flag is off")


func test_data_valid_and_counts() -> void:
	var tree := _tree()
	assert_eq(tree.validate(), [] as Array[String])
	var ids := tree.ids()
	assert_eq(ids.size(), 78)
	var tiers := {"minor": 0, "notable": 0, "keystone": 0}
	for id in ids:
		tiers[tree.tier_of(id)] += 1
		assert_true(id.begins_with("p_"), id)
	assert_eq(tiers["minor"], 48)
	assert_eq(tiers["notable"], 18)
	assert_eq(tiers["keystone"], 12)
	for det: String in tree.details():
		assert_eq(tree.passives_of(det).size(), 12, det)
	assert_eq(tree.deeds().size(), 16)


func test_icons_and_table_match() -> void:
	var tree := _tree()
	var text := FileAccess.get_file_as_string("res://docs/gdd/03-colony/passives-v2/table.json")
	var rows: Array = JSON.parse_string(text)
	assert_eq(rows.size(), tree.ids().size())
	for row: Dictionary in rows:
		assert_true(tree.def_of(str(row["id"])).size() > 0, "table row without data: " + str(row["id"]))
		assert_true(FileAccess.file_exists("res://" + str(row["icon"])), "missing icon " + str(row["icon"]))
		assert_true(str(row["description"]).length() <= 70)


func test_milestone_marks_once() -> void:
	var tree := _tree()
	var st := PassiveTreeV2.State.new()
	assert_eq(tree.on_skill_level(st, "mining", 2), 0)
	assert_eq(tree.on_skill_level(st, "mining", 3), 1)
	assert_eq(tree.on_skill_level(st, "mining", 3), 0)
	assert_eq(tree.on_skill_level(st, "mining", 7), 2)  # L6 only (L3 credited)
	assert_eq(tree.on_skill_level(st, "mining", 10), 3)
	assert_eq(st.marks_earned, 6)
	# a veteran joining at L6 earns the next mark at L10 only
	var vet := PassiveTreeV2.State.new()
	tree.set_baseline(vet, "crafting", 6)
	assert_eq(tree.on_skill_level(vet, "crafting", 9), 0)
	assert_eq(tree.on_skill_level(vet, "crafting", 10), 3)


func test_deeds_once() -> void:
	var tree := _tree()
	var st := PassiveTreeV2.State.new()
	assert_eq(tree.bump_counter(st, "rescues"), 1)
	assert_eq(tree.bump_counter(st, "rescues"), 0)
	assert_eq(tree.check_records(st, {"kills": {"crawler": 7, "brute": 3}, "waves_survived": 3}), 1 + 2 + 1)
	assert_eq(tree.check_records(st, {"kills": {"crawler": 7, "brute": 3}, "waves_survived": 3}), 0)
	assert_eq(tree.grant_deed(st, "d_debt_cleared"), 3)
	assert_eq(tree.grant_deed(st, "d_debt_cleared"), 0)
	assert_eq(tree.grant_deed(st, "d_nope"), 0)
	assert_eq(st.marks_earned, 8)


func test_allocation_rules() -> void:
	var tree := _tree()
	var st := _rich(tree, 3)
	assert_eq(tree.can_allocate(st, "p_nope", _ctx()), "unknown")
	assert_eq(tree.can_allocate(st, "p_pit_callouses", _ctx(2)), "gate_skill")
	assert_eq(tree.can_allocate(st, "p_pit_yard_shoulders", _ctx()), "requires")
	assert_eq(tree.can_allocate(st, "p_ledger_count_the_coins", _ctx()), "gate_deed")
	assert_true(tree.allocate(st, "p_pit_callouses", _ctx()))
	assert_eq(tree.can_allocate(st, "p_pit_callouses", _ctx()), "allocated")
	assert_true(tree.allocate(st, "p_pit_yard_shoulders", _ctx()))
	assert_eq(st.marks_free(), 1)
	assert_eq(tree.can_allocate(st, "p_pit_the_mule", _ctx()), "no_marks")  # notable costs 2
	tree.grant_deed(st, "d_first_installment")
	assert_eq(tree.can_allocate(st, "p_ledger_count_the_coins", _ctx()), "")


func test_keystone_requirements_and_limit() -> void:
	var tree := _tree()
	var st := _rich(tree, 60)
	assert_eq(tree.can_allocate(st, "p_pit_lifers_back", _ctx()), "requires")
	_pit_to_notables(tree, st)
	assert_eq(tree.can_allocate(st, "p_pit_lifers_back", _ctx()), "")
	assert_true(tree.allocate(st, "p_pit_lifers_back", _ctx()))
	# bridge keystone needs a notable in BOTH details
	assert_eq(tree.can_allocate(st, "p_key_clean_hands", _ctx()), "requires")
	for id in ["p_stacks_rubber_gloves", "p_stacks_valve_feel", "p_stacks_slow_pour"]:
		assert_true(tree.allocate(st, id, _ctx()))
	assert_eq(tree.can_allocate(st, "p_key_clean_hands", _ctx()), "")
	assert_true(tree.allocate(st, "p_key_clean_hands", _ctx()))
	assert_eq(tree.keystones_of(st).size(), 2)
	for id in ["p_ledger_count_the_coins", "p_ledger_quiet_mouth", "p_ledger_stash_pocket"]:
		tree.grant_deed(st, "d_first_installment")
		assert_true(tree.allocate(st, id, _ctx()), id)
	assert_eq(tree.can_allocate(st, "p_key_quota_hawk", _ctx()), "keystone_limit")


func test_undo_grace_and_dependents() -> void:
	var tree := _tree()
	var st := _rich(tree)
	assert_true(tree.allocate(st, "p_pit_callouses", _ctx(), 100))
	assert_true(tree.allocate(st, "p_pit_yard_shoulders", _ctx(), 120))
	assert_eq(tree.can_undo(st, "p_pit_callouses", 130), "dependents")
	assert_eq(tree.can_undo(st, "p_pit_yard_shoulders", 120 + 1800 + 1), "grace")
	assert_eq(tree.undo(st, "p_pit_yard_shoulders", 500), 1)
	assert_eq(tree.can_undo(st, "p_pit_yard_shoulders", 500), "not_allocated")
	assert_eq(tree.undo(st, "p_pit_callouses", 500), 1)
	assert_eq(st.marks_spent, 0)
	assert_eq(st.allocated.size(), 0)


func test_respec_cost_and_lockout() -> void:
	var tree := _tree()
	var st := _rich(tree, 60)
	assert_false(tree.can_respec(st))
	_pit_to_notables(tree, st)
	assert_true(tree.allocate(st, "p_pit_lifers_back", _ctx()))
	assert_eq(st.marks_spent, 17)
	var cost := tree.respec_cost(st, "fight")
	assert_eq(cost["item"], "refined_essence")
	assert_eq(cost["count"], 17)
	assert_eq(cost["standing"], 5)
	assert_eq(int(tree.respec_cost(st, "submit")["count"]), 9)
	assert_eq(int(tree.respec_cost(st, "escape")["count"]), 26)
	assert_eq(tree.respec(st, 1000, TPD), 17)
	assert_eq(st.marks_free(), 60)
	assert_eq(st.locked_until, 1000 + 3 * TPD)
	assert_eq(tree.can_allocate(st, "p_pit_callouses", _ctx(), 1000 + TPD), "locked")
	assert_eq(tree.can_allocate(st, "p_pit_callouses", _ctx(), 1000 + 3 * TPD), "")
	assert_eq(tree.respec(st, 2000, TPD), 0)


func test_mod_aggregation_and_caps() -> void:
	var tree := _tree()
	var st := _rich(tree, 60)
	assert_eq(tree.mod(st, "mining_speed"), 0.0)
	_pit_to_notables(tree, st)
	assert_true(is_equal_approx(tree.mod(st, "ore_yield"), 0.3))
	assert_true(is_equal_approx(tree.mod(st, "carry"), 0.75))
	assert_true(is_equal_approx(tree.xp_mult(st, "mining"), 1.15))
	assert_true(is_equal_approx(tree.xp_mult(st, "melee"), 1.0))
	assert_true(tree.allocate(st, "p_pit_lifers_back", _ctx()))
	assert_true(is_equal_approx(tree.mod(st, "carry"), 1.75))
	assert_true(is_equal_approx(tree.mod(st, "move_speed"), -0.2))
	assert_true(tree.summary(st).has("hunger"))
	# caps: a synthetic tree where waste stacks past the -0.4 floor
	var d: Dictionary = PassiveTreeV2.load_default()
	for p: Dictionary in d["passives"]:
		if str(p["id"]) == "p_stacks_flush_cycle":
			p["effects"]["waste_mult"] = -0.9
	var capped := PassiveTreeV2.new(d)
	var s2 := _rich(capped)
	for id in ["p_stacks_rubber_gloves", "p_stacks_scrub_hands", "p_stacks_second_skin", "p_stacks_flush_cycle"]:
		assert_true(capped.allocate(s2, id, _ctx()), id)
	assert_true(is_equal_approx(capped.mod(s2, "waste_mult"), -0.4))


func test_dossier_carry() -> void:
	var tree := _tree()
	var st := _rich(tree, 60)
	_pit_to_notables(tree, st)
	assert_true(tree.allocate(st, "p_pit_lifers_back", _ctx()))
	var carry := tree.dossier_carry(st)
	assert_eq(carry["marks"], 4)
	assert_eq(carry["known_for"], ["p_pit_lifers_back"] as Array[String])
	var vet := PassiveTreeV2.State.new()
	tree.apply_dossier(vet, carry)
	assert_eq(vet.marks_earned, 4)
	assert_eq(tree.cost_of(vet, "p_pit_lifers_back"), 0)
	assert_eq(tree.cost_of(st, "p_pit_lifers_back"), 3)


func test_save_roundtrip_and_determinism() -> void:
	var tree := _tree()
	var a := _rich(tree, 20)
	var b := _rich(tree, 20)
	for st in [a, b]:
		tree.grant_deed(st, "d_first_blood")
		assert_true(tree.allocate(st, "p_yard_yard_stance", _ctx(), 10))
		assert_true(tree.allocate(st, "p_yard_shiv_grip", _ctx(), 20))
		assert_true(tree.allocate(st, "p_yard_brawler", _ctx(), 30))
	assert_eq(tree.state_hash(a), tree.state_hash(b))
	var c := PassiveTreeV2.State.from_dict(a.to_dict())
	assert_eq(tree.state_hash(c), tree.state_hash(a))
	assert_eq(c.deeds.has("d_first_blood"), true)
	assert_eq(int(c.allocated_at["p_yard_brawler"]), 30)
	assert_true(is_equal_approx(tree.mod(c, "unarmed_damage"), 0.3))
