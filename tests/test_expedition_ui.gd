extends TestCase
## Expedition UI: map chips, expedition dialog flow, cargo dialog, and the
## GameController rebinding views when the active map changes. Uses a stub
## Campaign that follows the plan's fixed API (the real one is built in parallel).


class StubCampaign:
	extends RefCounted
	var maps: Array = []
	var active := 0
	var in_flight: Array = []
	var sent: Array = []
	var slung: Array = []

	func active_sim() -> Simulation:
		return maps[active]["sim"]

	func switch_map(id: int) -> bool:
		if id < 0 or id >= maps.size():
			return false
		active = id
		return true

	func step() -> void:
		active_sim().step()

	func map_info(id: int) -> Dictionary:
		return {"id": id, "biome": maps[id]["biome"], "kind": maps[id]["kind"], "alarm": id == 1}

	func send_expedition(biome: String, ids: Array, supplies: Dictionary) -> bool:
		sent.append([biome, ids, supplies])
		return true

	func sling_send(id: int, items: Dictionary) -> bool:
		slung.append([id, items])
		return true


func _stub() -> StubCampaign:
	var c := StubCampaign.new()
	c.maps = [
		{"id": 0, "biome": "start", "kind": "home", "sim": _sized_sim(3, 250)},
		{"id": 1, "biome": "ash", "kind": "outpost", "sim": _sized_sim(4, 96)},
	]
	c.in_flight = [{"from": 0, "to": 1, "items": {}, "arrive": 100}]
	return c


func _sized_sim(seed_value: int, n: int) -> Simulation:
	var sim := Simulation.new(seed_value, make_bus(), null, {"map_w": n, "map_h": n})
	sim.start_new_game()
	_sims.append(sim)
	return sim


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


func _panel(c: StubCampaign, mode := "expedition") -> ExpeditionPanel:
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
	assert_eq(c.sent.size(), 1)
	assert_eq(c.sent[0][1], [ids[0]])


func test_cannot_send_everyone() -> void:
	var c := _stub()
	var p := _panel(c)
	p.biome = "ash"
	for col in p.alive_colonists():
		p.toggle_colonist(col.id)
	assert_eq(p.crew.size(), p.alive_colonists().size() - 1)


func test_cargo_flow() -> void:
	var c := _stub()
	var p := _panel(c, "cargo")
	assert_true(_all_big(p.content))
	assert_false(p.confirm_cargo(), "no target or items")
	p.pick_target(1)
	var item := ""
	for id in p.supply_options():
		item = id
		break
	if item == "":
		return
	p.adjust(item, 2)
	assert_true(p.confirm_cargo())
	assert_eq(c.slung.size(), 1)
	assert_eq(c.slung[0][0], 1)


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
	assert_true(small.x < big.x, "96 map smaller than home")
	assert_eq(game.camera.world_size, small)
	assert_true(game.hud.map_switcher != null and game.hud.map_switcher.visible)
	game.switch_map(0)
	assert_eq(game.world.world_size(), big)
	game.campaign = null  # stub sims are owned by the test
	game.sim = null
