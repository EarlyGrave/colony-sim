extends TestCase
## Passives v2 r2 (sim/perks/passive_tree_v2.gd): data validity, marks, allocation graph, keystone
## excludes + limit, rule-flag aggregation, undo, respec, caps, dossier, determinism. The module is
## exercised directly (flag OFF: not wired into the sim, see test_flag_off).

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


func _alloc(tree: PassiveTreeV2, st: PassiveTreeV2.State, ids: Array) -> void:
	for id: String in ids:
		assert_true(tree.allocate(st, id, _ctx()), "allocate " + id + ": " + tree.can_allocate(st, id, _ctx()))


## The whole Pit card up to the five notables (6 minors + 5 notables = 16 marks).
func _pit_to_notables(tree: PassiveTreeV2, st: PassiveTreeV2.State) -> void:
	_alloc(tree, st, ["p_pit_callouses", "p_pit_yard_shoulders", "p_pit_pick_rhythm", "p_pit_scaffold_eye",
		"p_pit_the_mule", "p_pit_vein_reader", "p_pit_salvage_habit", "p_pit_long_shift", "p_pit_braced_walls",
		"p_pit_quiet_pick", "p_pit_foreman"])


func test_flag_off() -> void:
	var b: Dictionary = Defs.get_default().balance
	assert_true(b.has("passives_v2_enabled"))
	assert_false(bool(b["passives_v2_enabled"]))
	assert_true(Defs.get_default().passives_v2.is_empty(), "Defs must not load passives_v2.json while the flag is off")  # F11: field exists since integration


func test_data_valid_and_counts() -> void:
	var tree := _tree()
	assert_eq(tree.validate(), [] as Array[String])
	var ids := tree.ids()
	assert_eq(ids.size(), 90)
	var tiers := {"minor": 0, "notable": 0, "keystone": 0}
	for id in ids:
		tiers[tree.tier_of(id)] += 1
		assert_true(id.begins_with("p_"), id)
	assert_eq(tiers["minor"], 36)
	assert_eq(tiers["notable"], 30)
	assert_eq(tiers["keystone"], 24)
	var bridges := 0
	for det: String in tree.details():
		assert_eq(tree.passives_of(det).size(), 13, det)
		var nxt := str(tree.details()[det]["next"])
		assert_eq(tree.passives_of(det + "+" + nxt).size(), 2, det + "+" + nxt)
		bridges += 2
	assert_eq(bridges, 12)
	assert_eq(tree.deeds().size(), 16)


func test_keystones_are_rule_changes() -> void:
	var tree := _tree()
	for id in tree.ids():
		if tree.tier_of(id) != "keystone":
			assert_eq(tree.rules_of(id).size(), 0, id)
			assert_eq(tree.excludes_of(id).size(), 0, id)
			continue
		assert_true(tree.rules_of(id).size() >= 1, id + " keystone without a rule flag")
		for r in tree.rules_of(id):
			assert_true(tree.rule_consumers().has(r), id + " rule " + r + " has no consumer")
		var d := tree.def_of(id)
		assert_true(str(d["drawback"]).length() > 0, id)
	# the two keystones of one detail exclude each other
	for det: String in tree.details():
		var ks: Array[String] = []
		for id in tree.passives_of(det):
			if tree.tier_of(id) == "keystone":
				ks.append(id)
		assert_eq(ks.size(), 2, det)
		assert_true(tree.excludes_of(ks[0]).has(ks[1]), det)
		assert_true(tree.excludes_of(ks[1]).has(ks[0]), det)


func test_icons_and_table_match() -> void:
	var tree := _tree()
	var text := FileAccess.get_file_as_string("res://docs/gdd/03-colony/passives-v2/table.json")
	var rows: Array = JSON.parse_string(text)
	assert_eq(rows.size(), tree.ids().size())
	for row: Dictionary in rows:
		assert_true(tree.def_of(str(row["id"])).size() > 0, "table row without data: " + str(row["id"]))
		assert_true(FileAccess.file_exists("res://" + str(row["icon"])), "missing icon " + str(row["icon"]))
		assert_true(str(row["description"]).length() <= 70)
		assert_eq(str(row["rule"]) != "", tree.tier_of(str(row["id"])) == "keystone", str(row["id"]))


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
	# m5 opens from either n1 or n2
	tree.earn(st, 10)
	_alloc(tree, st, ["p_pit_pick_rhythm", "p_pit_vein_reader"])
	assert_eq(tree.can_allocate(st, "p_pit_long_shift", _ctx()), "")
	assert_eq(tree.can_allocate(st, "p_pit_braced_walls", _ctx()), "")


func test_keystone_requirements_excludes_and_limit() -> void:
	var tree := _tree()
	var st := _rich(tree, 80)
	assert_eq(tree.can_allocate(st, "p_pit_beast_of_burden", _ctx()), "requires")
	# minimal path to a detail keystone: m1 m2 n1 m3 n2 = 7 marks, keystone 3 -> 10
	_alloc(tree, st, ["p_pit_callouses", "p_pit_yard_shoulders", "p_pit_the_mule", "p_pit_pick_rhythm", "p_pit_vein_reader"])
	assert_eq(st.marks_spent, 7)
	assert_eq(tree.can_allocate(st, "p_pit_beast_of_burden", _ctx()), "")
	assert_eq(tree.can_allocate(st, "p_pit_mole", _ctx()), "requires")  # needs 2 of n2 n3 n5
	assert_true(tree.allocate(st, "p_pit_beast_of_burden", _ctx()))
	assert_eq(st.marks_spent, 10)
	_alloc(tree, st, ["p_pit_scaffold_eye", "p_pit_salvage_habit"])
	assert_eq(tree.can_allocate(st, "p_pit_mole", _ctx()), "excluded")  # the other school's keystone
	# bridge keystone needs a notable in BOTH details
	assert_eq(tree.can_allocate(st, "p_key_clean_hands", _ctx()), "requires")
	_alloc(tree, st, ["p_stacks_rubber_gloves", "p_stacks_valve_feel", "p_stacks_slow_pour"])
	assert_eq(tree.can_allocate(st, "p_key_clean_hands", _ctx()), "")
	assert_eq(tree.can_allocate(st, "p_key_tailings_eater", _ctx()), "")
	assert_true(tree.allocate(st, "p_key_clean_hands", _ctx()))
	assert_eq(tree.keystones_of(st).size(), 2)
	assert_eq(tree.can_allocate(st, "p_key_tailings_eater", _ctx()), "keystone_limit")
	tree.grant_deed(st, "d_first_installment")
	_alloc(tree, st, ["p_ledger_count_the_coins", "p_ledger_block_voice", "p_ledger_shot_caller"])
	assert_eq(tree.can_allocate(st, "p_key_quota_hawk", _ctx()), "keystone_limit")
	# cross-detail excludes: Clean Hands never refines, so Essence Lung is out even with room
	var st2 := _rich(tree, 80)
	_alloc(tree, st2, ["p_pit_callouses", "p_pit_yard_shoulders", "p_pit_the_mule",
		"p_stacks_rubber_gloves", "p_stacks_nose_plug", "p_stacks_lead_apron", "p_stacks_scrub_hands",
		"p_stacks_flush_cycle", "p_key_clean_hands"])
	assert_eq(tree.can_allocate(st2, "p_stacks_essence_lung", _ctx()), "excluded")


func test_rule_flags_aggregate() -> void:
	var tree := _tree()
	var st := _rich(tree, 80)
	assert_eq(tree.rules(st), {})
	assert_false(tree.has_rule(st, "unlimited_carry"))
	_alloc(tree, st, ["p_pit_callouses", "p_pit_yard_shoulders", "p_pit_the_mule", "p_pit_pick_rhythm", "p_pit_vein_reader"])
	assert_eq(tree.rules(st), {})
	assert_false(tree.summary(st).has("rules"))
	assert_true(tree.allocate(st, "p_pit_beast_of_burden", _ctx(), 100))
	assert_true(tree.has_rule(st, "unlimited_carry"))
	assert_true(tree.has_rule(st, "no_armor"))
	assert_false(tree.has_rule(st, "mining_only"))
	assert_eq(tree.rules(st).size(), 2)
	assert_true(is_equal_approx(tree.mod(st, "move_speed"), -0.25))
	assert_eq(tree.summary(st)["rules"], ["no_armor", "unlimited_carry"] as Array[String])
	# a second keystone adds its flags; undo clears the cache
	_alloc(tree, st, ["p_stacks_rubber_gloves", "p_stacks_valve_feel", "p_stacks_slow_pour"])
	assert_true(tree.allocate(st, "p_key_tailings_eater", _ctx(), 200))
	assert_eq(tree.rules(st).size(), 4)
	assert_true(tree.has_rule(st, "taint_immune"))
	assert_eq(tree.undo(st, "p_key_tailings_eater", 300), 3)
	assert_eq(tree.rules(st).size(), 2)
	assert_false(tree.has_rule(st, "taint_mining"))
	# respec clears every rule
	tree.respec(st, 1000, TPD)
	assert_eq(tree.rules(st), {})


func test_uncapped_rule_skips_cap() -> void:
	var tree := _tree()
	var st := _rich(tree, 80)
	_alloc(tree, st, ["p_stacks_rubber_gloves", "p_stacks_valve_feel", "p_stacks_slow_pour", "p_stacks_nose_plug",
		"p_stacks_lead_apron", "p_stacks_still_air", "p_stacks_cold_hands"])
	assert_true(is_equal_approx(tree.mod(st, "contamination_per_batch"), -0.4))  # -0.45 capped
	assert_true(tree.allocate(st, "p_stacks_slow_hands", _ctx()))
	assert_true(tree.has_rule(st, "uncapped_contamination_per_batch"))
	assert_true(is_equal_approx(tree.mod(st, "contamination_per_batch"), -1.05))
	assert_true(is_equal_approx(tree.mod(st, "operate_speed"), 0.1 - 0.05 - 0.1 - 0.5))


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
	assert_true(tree.allocate(st, "p_pit_mole", _ctx()))
	assert_eq(st.marks_spent, 19)
	var cost := tree.respec_cost(st, "fight")
	assert_eq(cost["item"], "refined_essence")
	assert_eq(cost["count"], 19)
	assert_eq(cost["standing"], 5)
	assert_eq(int(tree.respec_cost(st, "submit")["count"]), 10)
	assert_eq(int(tree.respec_cost(st, "escape")["count"]), 29)
	assert_eq(tree.respec(st, 1000, TPD), 19)
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
	assert_true(is_equal_approx(tree.mod(st, "ore_yield"), 0.35))
	assert_true(is_equal_approx(tree.mod(st, "carry"), 1.0))
	assert_true(is_equal_approx(tree.xp_mult(st, "mining"), 1.25))
	assert_true(is_equal_approx(tree.xp_mult(st, "melee"), 1.0))
	assert_true(tree.allocate(st, "p_pit_mole", _ctx()))
	assert_true(is_equal_approx(tree.mod(st, "ore_yield"), 0.85))
	assert_true(is_equal_approx(tree.mod(st, "mining_speed"), 1.1))
	assert_true(tree.summary(st).has("hunger"))
	# caps: a synthetic tree where waste stacks past the -0.4 floor
	var d: Dictionary = PassiveTreeV2.load_default()
	for p: Dictionary in d["passives"]:
		if str(p["id"]) == "p_stacks_flush_cycle":
			p["effects"]["waste_mult"] = -0.9
	var capped := PassiveTreeV2.new(d)
	var s2 := _rich(capped)
	for id in ["p_stacks_rubber_gloves", "p_stacks_scrub_hands", "p_stacks_flush_cycle"]:
		assert_true(capped.allocate(s2, id, _ctx()), id)
	assert_true(is_equal_approx(capped.mod(s2, "waste_mult"), -0.4))


func test_dossier_carry() -> void:
	var tree := _tree()
	var st := _rich(tree, 60)
	_pit_to_notables(tree, st)
	assert_true(tree.allocate(st, "p_pit_beast_of_burden", _ctx()))
	var carry := tree.dossier_carry(st)
	assert_eq(carry["marks"], 4)
	assert_eq(carry["known_for"], ["p_pit_beast_of_burden"] as Array[String])
	var vet := PassiveTreeV2.State.new()
	tree.apply_dossier(vet, carry)
	assert_eq(vet.marks_earned, 4)
	assert_eq(tree.cost_of(vet, "p_pit_beast_of_burden"), 0)
	assert_eq(tree.cost_of(st, "p_pit_beast_of_burden"), 3)


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
	assert_true(is_equal_approx(tree.mod(c, "unarmed_damage"), 0.5))


## Icons r3: every passive has its own glyph (pairwise >= MIN_ICON_DIFF differing pixels) and every
## detail has a branch logo sprite that exists.
const MIN_ICON_DIFF := 20


func _icon_bytes(icon_name: String) -> PackedByteArray:
	var tex := load("res://assets/sprites/%s.png" % icon_name) as Texture2D
	assert_true(tex != null, "missing sprite " + icon_name)
	if tex == null:
		return PackedByteArray()
	return tex.get_image().get_data()


func test_icons_unique_and_logos_exist() -> void:
	var d: Dictionary = PassiveTreeV2.load_default()
	var names: Array[String] = []
	var datas: Array[PackedByteArray] = []
	for p: Dictionary in d["passives"]:
		names.append(str(p["icon"]))
		datas.append(_icon_bytes(str(p["icon"])))
	assert_eq(names.size(), 90)
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a := datas[i]
			var b := datas[j]
			if a.size() != b.size() or a.is_empty():
				continue
			var diff := 0
			for k in range(0, a.size(), 4):
				if a[k] != b[k] or a[k + 1] != b[k + 1] or a[k + 2] != b[k + 2] or a[k + 3] != b[k + 3]:
					diff += 1
			assert_true(diff >= MIN_ICON_DIFF, "icons too similar (%d px): %s / %s" % [diff, names[i], names[j]])
	var details: Dictionary = d["details"]
	assert_eq(details.size(), 6)
	for det: String in details:
		var logo := str(details[det].get("logo", ""))
		assert_true(logo != "", "detail %s has no logo" % det)
		assert_true(ResourceLoader.exists("res://assets/sprites/%s.png" % logo), "logo sprite missing: " + logo)
