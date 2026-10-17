extends TestCase
## QA: every player command is recorded and replays to the same state.

const Cmds := ["designate_mine", "set_zone", "place_building", "deconstruct", "set_rule", "set_alarm",
	"add_bill", "remove_bill", "update_bill", "set_zone_filter", "set_zone_priority", "set_work_priority",
	"set_drafted", "order_move", "resolve_crisis", "answer_event", "set_turret_ammo_policy",
	"learn_perk", "use_perk", "respec_perks", "accept_contract", "decline_contract", "deliver_contract",
	"pay_debt", "set_quota", "choose_payoff", "set_patrol_route_text", "purify_cell"]


func test_session_with_every_command_replays() -> void:
	var sim := make_sim(21)
	QaBot.play(sim, 6000)
	var seen := {}
	for e: Array in sim.command_log:
		seen[e[1]] = true
	var missing: Array = Cmds.filter(func(c: String) -> bool: return not seen.has(c))
	# Commands that need a rare world state (crisis/event/contract/enemy) may not fire; core ones must.
	for core in ["designate_mine", "set_zone", "place_building", "add_bill", "update_bill", "set_rule", "set_alarm",
			"set_work_priority", "set_drafted", "order_move", "learn_perk", "pay_debt", "set_quota",
			"choose_payoff", "set_patrol_route_text", "purify_cell", "set_zone_filter", "set_zone_priority",
			"set_turret_ammo_policy", "accept_contract"]:
		assert_true(seen.has(core), "bot never issued %s" % core)
	print("  [qa] unexercised: ", missing)
	var res := SaveGame.load_json(SaveGame.to_json(sim), make_bus())
	assert_true(res["ok"], str(res["error"]))
	var sim2: Simulation = res["sim"]
	_sims.append(sim2)
	assert_eq(sim2.tick, sim.tick)
	_diff(QaBot.parts_of(sim), QaBot.parts_of(sim2))
	assert_eq(QaBot.full_hash(sim2), QaBot.full_hash(sim))
	sim.run_ticks(300)
	sim2.run_ticks(300)
	assert_eq(QaBot.full_hash(sim2), QaBot.full_hash(sim))


func test_every_view_command_records() -> void:
	# Each public mutating Simulation method must write to the command log (first line `_record`).
	var src := FileAccess.get_file_as_string("res://sim/core/simulation.gd")
	var allowed_unrecorded := ["start_new_game", "start_empty", "step", "run_ticks", "end_game", "day", "map_center",
		"cell_free_for_items", "can_place_building", "place_instant", "is_rule_on", "listen", "dispose", "set_patrol_route"]
	var lines := src.split("\n")
	for i in lines.size():
		var l := lines[i]
		if not l.begins_with("func ") or l.begins_with("func _"):
			continue
		var name := l.substr(5, l.find("(") - 5)
		if name in allowed_unrecorded or name.begins_with("get_") or name.begins_with("is_") or name.begins_with("can_"):
			continue
		assert_true(lines[i + 1].contains("_record("), "Simulation.%s mutates but does not _record" % name)


func _diff(a: Array, b: Array) -> void:
	for i in mini(a.size(), b.size()):
		if var_to_str(a[i]) != var_to_str(b[i]):
			print("  [qa] part %d differs:\n    %s\n    %s" % [i, var_to_str(a[i]).left(600), var_to_str(b[i]).left(600)])
			return

