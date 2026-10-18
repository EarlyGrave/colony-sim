extends TestCase
## R4X end to end on the real Campaign: research -> send 2 colonists + supplies to an ash outpost ->
## arrival -> autopilot yields cinder_ore -> sling cargo home lands on the exact tick ->
## save mid-flight, load, equal state_hash (and they stay equal afterwards).

var _camps: Array = []


func after_each() -> void:
	for c in _camps:
		c.dispose()
	_camps.clear()
	super.after_each()


func _factory() -> Callable:
	return func() -> Node: return make_bus()


## Queues a sling blueprint with the player command and lets the colonists build it.
func _build_sling(c: Campaign) -> void:
	var sim := c.active_sim()
	var near := sim.map_center() + Vector2i(-8, 5)
	var spot := Vector2i(-1, -1)
	for r in range(0, 20):
		for dx in range(-r, r + 1):
			if spot.x < 0 and sim.can_place_building("sling", near + Vector2i(dx, r)) == "":
				spot = near + Vector2i(dx, r)
	assert_true(spot.x >= 0)
	assert_true(sim.place_building("sling", spot) != null)
	for i in 6000:
		c.step()
		for b in sim.buildings.list:
			if b.def_id == "sling":
				return
	fail("sling was not built")


func _cell_with(sim: Simulation, item: String) -> Vector2i:
	var ctr := sim.map_center()
	for y in range(-8, 9):
		for x in range(-8, 9):
			if sim.items.item_at(ctr + Vector2i(x, y)) == item:
				return ctr + Vector2i(x, y)
	return Vector2i(-1, -1)


func test_full_expedition_cycle_with_save_mid_flight() -> void:
	var c := Campaign.new(21, _factory(), peaceful_defs())
	c.start()
	_camps.append(c)
	var home := c.home_sim()
	var ids: Array = []
	for col in home.colonists.list:
		if ids.size() < 2:
			ids.append(col.id)
	var supplies := {"raw_food": 12, "essence_ore": 30}  # from the start stockpile

	# 1. gated by research
	assert_false(c.send_expedition("ash", ids, supplies))
	home.research.done.append("expeditions")
	var alive_before := home.colonists.list.size()
	assert_true(c.send_expedition("ash", ids, supplies))
	assert_eq(home.colonists.list.size(), alive_before - 2)

	# 2. arrival at exactly travel_ticks
	var travel := int(c.cfg["travel_ticks"])
	for i in travel - 1:
		c.step()
	assert_eq(c.maps.size(), 1)
	c.step()
	assert_eq(c.maps.size(), 2)
	assert_eq(c.entry(1)["biome"], "ash")
	assert_eq(c.entry(1)["sim"].colonists.list.size(), 2)

	# 3. autopilot yields cinder_ore for the unattended outpost (3 map-days)
	for i in 3 * 600:
		c.step()
	var led: Dictionary = c.ledgers[1]
	assert_false(bool(led["lost"]))
	assert_gt(float(led["buffer"].get("cinder_ore", 0)), 0.0)

	# 4. visit the outpost: buffer is delivered, stock it, build the sling, fire a crate home
	assert_true(c.switch_map(1))
	var out := c.active_sim()
	assert_true(led["buffer"].is_empty())
	var ore := _cell_with(out, "cinder_ore")
	assert_true(ore.x >= 0, "cinder_ore dropped near the outpost HQ")
	out.set_zone(ore, "stockpile")
	assert_gt(float(out.items.count_stored("cinder_ore")), 0.0)
	_build_sling(c)
	var n := mini(5, out.items.count_stored("cinder_ore"))
	assert_true(c.sling_send(0, {"cinder_ore": n}))
	var t_send := c.tick
	var sling_travel := int(Sling.sling_def(c)["travel"])
	assert_true(c.switch_map(0))

	# 5. save mid-flight, load, equal hash
	for i in 50:
		c.step()
	var res := SaveGame.campaign_from_json(SaveGame.campaign_to_json(c), _factory(), peaceful_defs())
	assert_true(res["ok"], str(res["error"]))
	var c2: Campaign = res["campaign"]
	_camps.append(c2)
	assert_eq(c2.in_flight.size(), 1)
	# (the tech grant above bypasses the research commands, so it is repeated on the loaded copy)
	c2.home_sim().research.done.append("expeditions")
	assert_eq(c2.state_hash(), c.state_hash())

	# 6. the crate lands on the exact tick, in both copies, and they stay equal
	while c.tick < t_send + sling_travel - 1:
		c.step()
		c2.step()
	assert_eq(c.in_flight.size(), 1)
	assert_eq(c2.in_flight.size(), 1)
	c.step()
	c2.step()
	assert_eq(c.tick, t_send + sling_travel)
	assert_true(c.in_flight.is_empty())
	assert_true(c2.in_flight.is_empty())
	var landed := 0
	for cmd: Array in c.home_sim().command_log:
		if cmd[1] == "receive_cargo" and str(cmd[2][0]).contains("cinder_ore") and int(cmd[0]) == c.home_sim().tick:
			landed += 1
	assert_eq(landed, 1)
	assert_eq(c2.state_hash(), c.state_hash())


func test_game_runs_a_campaign_and_autosaves_v3() -> void:
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	host.add_child(game)
	game.new_game(7)
	assert_true(game.campaign != null)
	assert_eq(game.sim, game.campaign.home_sim())
	assert_eq(game.sim.seed_value, 7)  # home keeps the unchanged seed
	for i in 30:
		game._r4e_step()
	var path := "user://r4x_test_save.json"
	var d: Dictionary = SaveGame.campaign_to_dict(game.campaign)
	assert_eq(int(d["version"]), 3)
	var back := SaveGame.campaign_from_json(JSON.stringify(d), game._r4e_bus)
	assert_true(back["ok"], str(back["error"]))
	back["campaign"].dispose()
	# v2 single-map saves are wrapped into a campaign
	game._r4e_wrap(game.sim)
	assert_eq(game.campaign.home_sim(), game.sim)
	game.campaign.maps.clear()  # sims are disposed with the game
	game.campaign = null
	DirAccess.remove_absolute(path)
