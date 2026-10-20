extends TestCase
## F6 W3: pilot rename verb, epilogue echoes, masterwork line, win screen.


func _spawn_pilot(sim: Simulation) -> Colonist:
	sim.quests.quests["t"] = {"refs": {}}
	sim.quests._apply_effects("t", [{"verb": "spawn_colonist", "as": "pilot"}, {"verb": "rename", "who": "pilot", "to": "dead"}])
	var c := sim.colonists.get_by_id(int(sim.quests.quests["t"]["refs"]["pilot"]))
	sim.quests.quests.erase("t")
	return c


func test_rename_with_dead() -> void:
	var sim := make_sim(3)
	var victim: Colonist = sim.colonists.list[0]
	var nm := str(victim.display_name)
	sim.colonists.kill(victim)
	var p := _spawn_pilot(sim)
	assert_true(p != null)
	assert_eq(str(p.display_name), nm)


func test_rename_without_dead_keeps_name() -> void:
	var sim := make_sim(3)
	var before := sim.colonists.list.size()
	var p := _spawn_pilot(sim)
	assert_eq(sim.colonists.list.size(), before + 1)
	assert_true(str(p.display_name) != "" and str(p.display_name) != QuestLog.DEAD_FALLBACK)


func test_epilogue_unchanged_without_flags() -> void:
	var sim := make_sim(3)
	for id: String in ["submit", "fight", "escape", "remission"]:
		assert_eq(EndingSystem.epilogue_for(id, sim), EndingSystem.epilogue(id), id)


func test_echo_only_with_flag() -> void:
	var sim := make_sim(3)
	sim.quests.set_flag("r4_seat_kept")
	var ep := EndingSystem.epilogue_for("submit", sim)
	assert_true(ep.has("Seat 7 stayed empty. Someone kept the door."))
	assert_false(ep.has("A name was sold. It still answers to the buyer."))
	assert_eq(ep.size(), EndingSystem.epilogue("submit").size() + 1)
	assert_eq(EndingSystem.epilogue_for("fight", sim).size(), EndingSystem.epilogue("fight").size())


func test_echo_text_length() -> void:
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flavor.json"))
	for id: String in j["epilogue_echo"]:
		for e: Dictionary in j["epilogue_echo"][id]:
			assert_true(str(e["line"]).length() <= 70, str(e["line"]))


func test_masterwork_line() -> void:
	var sim := make_sim(3)
	sim.fixation.masterworks.append({"cid": 0, "who": "A", "base": "x", "gear_id": 1, "name": "Ann's Pick"})
	sim.fixation.masterworks.append({"cid": 1, "who": "B", "base": "x", "gear_id": 2, "name": "Bo's Vest"})
	sim.fixation.masterworks.append({"cid": 2, "who": "C", "base": "x", "gear_id": 3, "name": "Cy's Hat"})
	var ep := EndingSystem.epilogue_for("escape", sim)
	assert_eq(str(ep[ep.size() - 1]), "Hung on the wall: Ann's Pick, Bo's Vest.")


func test_win_screen_echo_and_buttons() -> void:
	var sim := make_sim(3)
	sim.quests.set_flag("r4_seat_kept")
	var st := WinScreen.stats_from(sim)
	st["ending"] = "submit"
	st["epilogue_echo"] = EndingSystem.echo_lines("submit", sim)
	var w := WinScreen.new(st)
	var base := WinScreen.epilogue_lines("submit").size() - 1
	assert_eq(w.epilogue_box.get_child_count(), base + 1)
	assert_eq(w.find_children("*", "Button", true, false).size(), 3)
	w.free()
