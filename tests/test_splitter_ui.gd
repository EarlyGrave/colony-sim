extends TestCase
## L2: Logic tool row, splitter sheet (3 taps node -> row -> item), glyph data, button sizes.


func _make_game() -> GameController:
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	host.add_child(game)
	return game


func test_logic_row_has_four_big_buttons() -> void:
	var game := _make_game()
	var ap := game.auto_panel
	assert_true(ap._logic_row != null and not ap._logic_row.visible)
	assert_eq(ap._logic_row.get_child_count(), 5)  # 4 kinds + Undo
	for b: Button in ap._logic_row.get_children():
		assert_true(b.custom_minimum_size.x >= 64 and b.custom_minimum_size.y >= 64)
	ap._logic_btn.button_pressed = true
	assert_true(ap._logic_row.visible)


func test_locked_kind_shows_tech_name() -> void:
	var game := _make_game()
	game.sim.research.gating = true
	game.auto_panel.refresh_locks(game.sim)
	var owner := game.sim.research.building_tech("splitter_basic")
	if owner == "":
		return  # L5 defs not merged yet
	var b: Button = game.auto_panel._buttons["node_1"]
	assert_true(b.disabled)
	assert_true(b.text.contains("("))


func test_sheet_three_taps_sets_filter() -> void:
	var game := _make_game()
	var sim := game.sim
	if not (sim.logistics.has_method("place_node") and sim.logistics.has_method("set_filter")):
		return  # L1 not merged yet
	sim.research.gating = false
	var c := Vector2i(-1, -1)
	for y in sim.map.height:
		for x in sim.map.width:
			if c.x < 0 and sim.can_belt_cell_error(Vector2i(x, y)) == "":
				c = Vector2i(x, y)
	assert_true(sim.place_belt_node(2, c, 1))
	game._l2_tap(c)  # tool is "inspect" -> opens the sheet
	var sp := game.splitter_panel
	assert_true(sp.visible)
	var slot: Button = sp._box.find_child("slot1", true, false)  # tap 2: Front row
	assert_true(slot != null and slot.size.y >= 0 and slot.custom_minimum_size.y >= 64)
	slot.pressed.emit()
	var pick: Button = sp._box.find_child("pick_iron_ore", true, false)  # tap 3: item
	if pick == null:
		pick = sp._box.find_child("pick_overflow", true, false)
		assert_true(pick != null)
		pick.pressed.emit()
		assert_eq(sim.get_splitter_filter(c, 1), "overflow")
	else:
		pick.pressed.emit()
		assert_eq(sim.get_splitter_filter(c, 1), "iron_ore")
	for b in sp.find_children("*", "Button", true, false):
		assert_true((b as Button).custom_minimum_size.y >= 64, "button %s" % b.text)


func test_slot_labels_follow_flow_direction() -> void:
	assert_eq(SplitterPanel.slot_label(1, 0), "Left ^")  # east-facing: left is north
	assert_eq(SplitterPanel.slot_label(1, 2), "Right v")
	assert_eq(SplitterPanel.slot_label(0, 1), "Front ^")
