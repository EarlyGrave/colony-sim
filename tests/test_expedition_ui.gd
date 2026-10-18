extends TestCase
## Expedition UI: map chips, expedition dialog flow, cargo dialog, and the
## GameController rebinding views when the active map changes. Real Campaign.


var _camps: Array = []


func after_each() -> void:
	for c in _camps:
		c.dispose()
	_camps.clear()
	super.after_each()


func _stub() -> Campaign:
	var c := Campaign.new(3, func() -> Node: return make_bus(), peaceful_defs())
	c.start()
	_camps.append(c)
	c.home_sim().research.done.append("expeditions")
	c.add_outpost("ash", [{"name": "Rook"}], {"essence_ore": 40})
	c.ledgers[1]["integrity"] = 50  # damaged: alarm badge
	c.in_flight.append({"kind": "crate", "from": 1, "to": 0, "items": {}, "arrive": 100000})
	return c


func _buttons(n: Node, out: Array[Button]) -> void:
	for ch in n.get_children():
		if ch is Button:
			out.append(ch)
		_buttons(ch, out)


func _all_big(n: Node) -> bool:
	var bs: Array[Button] = []
	_buttons(n, bs)
	for b in bs:
		if b.custom_minimum_size.x < 64 or b.custom_minimum_size.y < 64:
			return false
	return true


func _panel(c: Campaign, mode := "expedition") -> ExpeditionPanel:
	var p := ExpeditionPanel.new()
	_owned_nodes.append(p)
	p.setup(c, mode)
	p.open(c.active_sim())
	return p


func test_switcher_chips_big_with_badges() -> void:
	var c := _stub()
	var sw := MapSwitcher.new()
	_owned_nodes.append(sw)
	sw.bind(c)
	assert_true(_all_big(sw))
	assert_true(sw.chip_text(0).contains("[1]"), "in-flight badge")
	assert_true(sw.chip_text(1).ends_with("!"), "alarm badge")
	var got := [-1]
	sw.map_chosen.connect(func(id: int) -> void: got[0] = id)
	sw.get_node("chip_1").pressed.emit()
	assert_eq(got[0], 1)


func test_expedition_flow_calls_send_once() -> void:
	var c := _stub()
	var p := _panel(c)
	assert_true(_all_big(p.content))
	p.biome = "ash"
	p.step = ExpeditionPanel.Step.CREW
	var ids: Array[int] = []
	for col in p.alive_colonists():
		ids.append(col.id)
	p.toggle_colonist(ids[0])
	p.next()
	p.next()
	assert_eq(p.step, ExpeditionPanel.Step.CONFIRM)
	assert_true(_all_big(p.content))
	assert_true(p.confirm())
	assert_false(p.confirm(), "state reset after sending")
	var parties := 0
	for f: Dictionary in c.in_flight:
		if f["kind"] == "party":
			parties += 1
			assert_eq((f["crew"] as Array).size(), 1)
	assert_eq(parties, 1)
	assert_eq(c.log.back()[1], "send_expedition")


func test_cannot_send_everyone() -> void:
	var c := _stub()
	var p := _panel(c)
	p.biome = "ash"
	for col in p.alive_colonists():
		p.toggle_colonist(col.id)
	assert_eq(p.crew.size(), p.alive_colonists().size() - 1)


func _place_sling(sim: Simulation) -> void:
	var near := sim.map_center() + Vector2i(-8, 5)
	for r in range(0, 20):
		for dx in range(-r, r + 1):
			if sim.buildings.placement_error("sling", near + Vector2i(dx, r)) == "":
				assert_true(sim.place_instant("sling", near + Vector2i(dx, r)) != null)
				return


func test_cargo_flow() -> void:
	var c := _stub()
	c.switch_map(1)
	var out := c.active_sim()
	_place_sling(out)
	var cell := out.map_center() + Vector2i(-6, 2)
	out.set_zone(cell, "stockpile")
	out.items.add_at(cell, "essence_ore", 6)
	var p := _panel(c, "cargo")
	assert_true(_all_big(p.content))
	assert_false(p.confirm_cargo(), "no target or items")
	assert_eq(p.cargo_targets(), [0] as Array[int])
	p.pick_target(0)
	p.adjust("essence_ore", 2)
	assert_true(p.confirm_cargo())
	assert_eq(c.log.back()[1], "sling_send")
	assert_eq(Sling.in_flight_from(c, 1), 2)  # the fake crate from _stub + the real one


func test_game_switch_swaps_sim_and_world_size() -> void:
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	host.add_child(game)
	game.new_game(1)
	var c := _stub()
	game.attach_campaign(c)
	assert_eq(game.sim, c.maps[0]["sim"])
	var big: Vector2 = game.world.world_size()
	assert_true(game.switch_map(1))
	assert_eq(game.sim, c.maps[1]["sim"])
	var small: Vector2 = game.world.world_size()
	assert_ne(small, big, "outpost map has its own size")
	assert_eq(game.camera.world_size, small)
	assert_true(game.hud.map_switcher != null and game.hud.map_switcher.visible)
	game.switch_map(0)
	assert_eq(game.world.world_size(), big)
	game.campaign = null  # stub sims are owned by the test
	game.sim = null
