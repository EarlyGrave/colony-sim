extends TestCase
## F11W4: Record board, Record button on the colonist sheet, trait badge row + sheet. Reads sim state only; all
## changes go through Simulation commands (sim.allocate_passive / undo_passive / respec_passives).


func _on_sim(seed_value := 5) -> Simulation:
	var defs := peaceful_defs()
	defs.balance["passives_v2_enabled"] = true
	var sim := make_sim(seed_value, true, 24, 24, defs)
	return sim


func _board(sim: Simulation, cid: int) -> PassiveBoard:
	var b := PassiveBoard.new()
	_owned_nodes.append(b)
	b.focus_colonist(cid)
	b.open(sim)
	return b


func _colonist(sim: Simulation) -> Colonist:
	var c: Colonist = sim.colonists.list[0]
	c.skills.levels["mining"] = 3
	c.skills.levels["operating"] = 3
	return c


func _section_box(sim: Simulation, c: Colonist) -> VBoxContainer:
	var box := VBoxContainer.new()
	_owned_nodes.append(box)
	var target := {"kind": "colonist", "colonist": c, "request_panel": func(_p: String, _i: int) -> void: pass}
	(ColonistSectionScript.new() as InspectorSection).build(sim, target, box)
	return box


const ColonistSectionScript := preload("res://view/panels/sections/colonist_section.gd")


func _buttons(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for ch in n.get_children():
		_buttons(ch, out)


func _record_button(box: Node) -> Button:
	var all: Array = []
	_buttons(box, all)
	for b: Button in all:
		if b.text.begins_with("Record"):
			return b
	return null


func test_record_button_hidden_when_flag_off() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	assert_false(sim.passives.enabled(), "flag stays off by default")
	assert_true(_record_button(_section_box(sim, sim.colonists.list[0])) == null, "no Record button with the flag off")


func test_record_button_new_badge_with_free_marks() -> void:
	var sim := _on_sim()
	var c := _colonist(sim)
	var rb := _record_button(_section_box(sim, c))
	assert_true(rb != null, "Record button with the flag on")
	assert_false(rb.text.contains("NEW"), "no NEW badge without marks")
	assert_true(rb.custom_minimum_size.y >= 64.0, "button is >= 64 px")
	sim.grant_passive_marks(c.id, 3, "test")
	assert_true(_record_button(_section_box(sim, c)).text.contains("NEW"), "NEW badge once marks_free > 0")


func test_rule_flag_lines_on_colonist_sheet() -> void:
	var sim := _on_sim()
	var c := _colonist(sim)
	sim.grant_passive_marks(c.id, 30, "test")
	var tree := PassiveBoard.tree()
	# allocate the cheapest legal path to any keystone with a rule flag
	var st := sim.passives.state_of(c)
	var guard := 0
	while tree.keystones_of(st).is_empty() and guard < 40:
		guard += 1
		var progressed := false
		for id in tree.passives_of("pit"):
			var reason := sim.passives.can_allocate(c, id)
			if reason == "" and (str(tree.def_of(id)["tier"]) != "keystone" or not tree.rules_of(id).is_empty()):
				sim.allocate_passive(c.id, id)
				progressed = true
				break
		if not progressed:
			break
	assert_false(tree.keystones_of(st).is_empty(), "a keystone was reachable")
	if tree.rules(st).is_empty():
		return
	var box := _section_box(sim, c)
	var texts: Array[String] = []
	_labels(box, texts)
	for r: String in tree.rules(st):
		assert_true(texts.has(str(tree.rule_consumers()[r]["rule"])), "rule line for " + r)


func _labels(n: Node, out: Array[String]) -> void:
	if n is Label:
		out.append((n as Label).text)
	for ch in n.get_children():
		_labels(ch, out)


func test_board_cards_every_node_64px_and_state_matches_reason() -> void:
	var sim := _on_sim()
	var c := _colonist(sim)
	sim.grant_passive_marks(c.id, 4, "test")
	var board := _board(sim, c.id)
	var seen := 0
	for d: String in PassiveBoard.tree().details():
		board._pick_detail(d)
		assert_eq(board.node_buttons.size(), 17, "%s card: 13 nodes + 2 + 2 seam bridges" % d)
		for id: String in board.node_buttons:
			var b: Button = board.node_buttons[id]
			assert_true(b.size.x >= 64.0 and b.size.y >= 64.0, "%s node is >= 64 px (%s)" % [id, b.size])
			board._select(id)
			var reason := sim.passives.can_allocate(c, id)
			if sim.passives.state_of(c).allocated.has(id):
				assert_true(board.allocate_button == null and board.undo_button != null, id + " allocated shows Undo")
			else:
				assert_true(board.allocate_button != null, id + " shows Allocate")
				assert_eq(board.allocate_button.disabled, reason != "", "%s button state matches reason '%s'" % [id, reason])
				if reason != "":
					assert_true(PassiveBoard.reason_text(sim, sim.passives.state_of(c), id, reason) != "", id + " reason has copy")
			seen += 1
	assert_eq(seen, 6 * 17, "visited every node of every card")


func test_allocate_undo_respec_through_commands() -> void:
	var sim := _on_sim()
	var c := _colonist(sim)
	sim.grant_passive_marks(c.id, 3, "test")
	var board := _board(sim, c.id)
	board._pick_detail("pit")
	var entry := "p_pit_callouses"
	board._select(entry)
	assert_false(board.allocate_button.disabled, "entry allocatable with mark + skill")
	board.allocate_button.pressed.emit()
	assert_true(sim.passives.state_of(c).allocated.has(entry), "allocated through sim.allocate_passive")
	assert_true(board.undo_button != null and not board.undo_button.disabled, "undo inside the grace window")
	board.undo_button.pressed.emit()
	assert_false(sim.passives.state_of(c).allocated.has(entry), "undone through sim.undo_passive")
	board._select(entry)
	board.allocate_button.pressed.emit()
	assert_true(board.respec_button != null and board.respec_button.disabled, "respec disabled without essence to pay")
	var cost := sim.passives.respec_cost(c)
	var cell := c.cell
	for off: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(2, 0), Vector2i(0, 2)]:
		if sim.set_zone(c.cell + off, "stockpile"):
			cell = c.cell + off
			break
	assert_ne(cell, c.cell, "found a stockpile cell")
	sim.items.drop(cell, str(cost["item"]), int(cost["count"]))
	board._sig = ""
	board.refresh()
	assert_true(board.respec_button != null and not board.respec_button.disabled, "respec enabled with an allocation and essence")
	board.respec_button.pressed.emit()
	assert_true(board.respec_button.text.begins_with("Tap again"), "respec asks twice")
	board.respec_button.pressed.emit()
	assert_true(sim.passives.state_of(c).allocated.is_empty(), "respec cleared the board")


func test_keystone_sheet_shows_rule_and_drawback() -> void:
	var sim := _on_sim()
	var c := _colonist(sim)
	var board := _board(sim, c.id)
	board._pick_detail("pit")
	board._select("p_pit_beast_of_burden")
	var texts: Array[String] = []
	_labels(board._text_box, texts)
	var joined := "\n".join(texts)
	assert_true(joined.contains("Rule: "), "Rule line")
	assert_true(joined.contains("Drawback: "), "Drawback line")
	assert_true(joined.contains("Needs "), "requirement line: " + joined)


func test_reason_copy_covers_every_code() -> void:
	var sim := _on_sim()
	var st := PassiveTreeV2.State.new()
	for code in ["gate_skill", "gate_deed", "requires", "excluded", "keystone_limit", "no_marks", "locked"]:
		var id := "p_pit_beast_of_burden" if code != "gate_deed" else "p_ledger_first_page"
		if PassiveBoard.tree().def_of(id).is_empty():
			id = "p_pit_callouses"
		assert_true(PassiveBoard.reason_text(sim, st, id, code) != "", "copy for " + code)


func test_trait_badges_fit_one_row_and_sheet_shows_since_day() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	var ts := TraitSystemV3.new(sim)
	var c: Colonist = sim.colonists.list[0]
	var ids := ts.ids()
	var picked: Array[String] = []
	for id in ids:
		if picked.size() < 5:
			picked.append(id)
	c.bio["traits_v3"] = picked
	c.bio["trait_log"] = [{"day": 7, "id": picked[4], "op": "add", "src": "test"}]
	var box := VBoxContainer.new()
	_owned_nodes.append(box)
	box.custom_minimum_size.x = 310.0
	var badges := TraitSheet.build_v3(ts, c, box)
	assert_eq(badges.size(), 5, "five badges")
	_sort(box)
	var y0 := -1.0
	for id: String in badges:
		var b: Button = badges[id]
		assert_true(b.custom_minimum_size.x >= 60.0 and b.custom_minimum_size.y >= 64.0, "badge size")
		assert_true(b.icon != null, id + " has an icon")
		if y0 < 0.0:
			y0 = b.position.y
		assert_eq(b.position.y, y0, "5 badges in one row at inspector width")
	TraitSheet.selected = {"cid": c.id, "id": picked[4]}
	var box2 := VBoxContainer.new()
	_owned_nodes.append(box2)
	TraitSheet.build_v3(ts, c, box2)
	var texts: Array[String] = []
	_labels(box2, texts)
	TraitSheet.selected = {}
	assert_true(texts.has("Since day 7"), "since-day line: %s" % str(texts))


func _sort(n: Node) -> void:
	for ch in n.get_children():
		_sort(ch)
	if n is Container:
		(n as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)


func test_v2_text_list_fallback_when_v3_absent() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	assert_true(TraitSheet.v3(sim) == null, "flag off -> no v3 sheet")
	var c: Colonist = sim.colonists.list[0]
	var box := VBoxContainer.new()
	_owned_nodes.append(box)
	TraitSheet.add_v2_list(sim, c, box)
	assert_eq(box.get_child_count(), (c.bio.get("traits", []) as Array).size(), "one line per v2 trait")
