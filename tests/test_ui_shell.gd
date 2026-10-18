extends TestCase


func _make_game() -> GameController:
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	var tree := Engine.get_main_loop() as SceneTree
	# The root is busy while the runner scene is still starting, so attach to the runner node.
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	host.add_child(game)
	return game


func test_registry_entries_are_valid() -> void:
	var ids := {}
	for e: Array in PanelRegistry.panel_entries():
		assert_eq(e.size(), 3, "panel entry shape")
		assert_true(not ids.has(e[0]), "duplicate panel id " + str(e[0]))
		ids[e[0]] = true
		assert_true(PanelRegistry.make_panel(e[0]) != null, "panel loads: " + str(e[0]))
	var sections := PanelRegistry.make_sections()
	assert_eq(sections.size(), PanelRegistry.INSPECTOR_SECTIONS.size(), "all sections load")


func test_inspector_sections_apply_by_target() -> void:
	var sim := make_sim(7)
	var sections := PanelRegistry.make_sections()
	var col: Colonist = sim.colonists.list[0]
	var t := {"kind": "colonist", "colonist": col, "building": null, "cell": col.cell}
	var n := 0
	for s in sections:
		if s.applies(sim, t):
			n += 1
			var box := VBoxContainer.new()
			s.build(sim, t, box)
			assert_true(box.get_child_count() > 0)
			box.free()
	assert_gt(n, 0, "at least the colonist section applies")


func test_letter_log_collects_bus_events() -> void:
	var sim := make_sim(3)
	var letters := LetterLog.new()
	letters.bind(sim, sim.bus)
	sim.bus.story_event.emit("x", "Hello")
	sim.bus.wave_started.emit(1, 5.0)
	assert_true(letters.entries.size() >= 2)
	assert_eq(letters.unread, letters.entries.size())
	letters.mark_read()
	assert_eq(letters.unread, 0)
	var n := letters.entries.size()
	letters.unbind()
	sim.bus.story_event.emit("x", "more")
	assert_eq(letters.entries.size(), n)


func test_game_scene_runs_and_opens_panels() -> void:
	var game := _make_game()
	assert_true(game.sim != null)
	for i in 120:
		game.sim.step()
	var hud := game.hud
	hud._process(0.3)
	hud.toggle_panel("letters")
	assert_eq(hud._side_id, "letters")
	hud.toggle_panel("letters")
	assert_eq(hud._side_id, "")
	var col: Colonist = game.sim.colonists.list[0]
	game._select_colonist(col.id)
	assert_eq(hud._side_id, "inspector")
	hud._process(0.3)
	game.hud.show_message("a", 1.0)
	game.hud.show_message("b", 1.0)
	hud._process(0.3)
	game.new_game(11)
	hud._process(0.3)
	assert_eq(hud._side_id, "")
