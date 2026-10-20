extends TestCase
## F5 W2: petition waivers (alt payments): Volunteer Detail (P1) and Informant Report (P3).


func _sim(seed_value: int = 5, n_col: int = 4) -> Simulation:
	var d := peaceful_defs()
	d.balance["e1_enabled"] = true
	var sim := make_sim(seed_value, false, 32, 32, d)
	for i in n_col:
		sim.colonists.spawn(Vector2i(4 + i, 4))
	sim.buildings.place("warden_terminal", Vector2i(10, 10), false)
	sim.run_ticks(1)
	sim.milestones.done_tiers = [0, 1, 2]
	return sim


func test_detail_completes_like_normal_payment() -> void:
	var sim := _sim()
	var phases: Array = []
	sim.bus.petition_phase_done.connect(func(p: int) -> void: phases.append(p))
	assert_true(sim.petition.alt_available(1))
	assert_true(sim.deliver_petition_alt(1, "detail"))
	assert_true(sim.petition.detail_active())
	assert_false(sim.deliver_petition_alt(1, "detail"), "already running")
	sim.run_ticks(2400)
	assert_eq(phases, [1], "phase paid exactly once")
	assert_false(sim.petition.detail_active())
	assert_eq(sim.petition.next_phase(), 2)


func test_unavailable_changes_no_state() -> void:
	var sim := _sim(5, 2)  # only 2 colonists: no 3 volunteers
	var before := SaveGame.state_hash(sim)
	assert_false(sim.petition.alt_available(1))
	assert_false(sim.deliver_petition_alt(1, "detail"))
	assert_false(sim.deliver_petition_alt(2, "detail"), "phase 2 has no alt")
	assert_false(sim.deliver_petition_alt(1, "bogus"))
	assert_false(sim.deliver_petition_alt(3, "informant"), "locked: not the current phase")
	assert_eq(SaveGame.state_hash(sim), before)
	var row: Dictionary = sim.get_petition_state()["phases"][0]
	assert_false(bool(row["alt"]["available"]))
	assert_true(str(row["alt"]["reason"]) != "")


func test_informant_alt_hidden_when_covert_off() -> void:
	var sim := _sim()
	sim.petition.done_phases = [1, 2]
	assert_false(sim.petition.alt_available(3))
	assert_false(sim.deliver_petition_alt(3, "informant"))
	assert_eq(sim.petition.done_phases.size(), 2)


func test_informant_alt_pays_with_suspicion_and_standing() -> void:
	var d := peaceful_defs()
	d.balance["e1_enabled"] = true
	d.contraband["enabled"] = true
	var sim := make_sim(5, false, 32, 32, d)
	sim.blocks.cfg["enabled"] = true
	for i in 9:
		sim.colonists.spawn(Vector2i(4 + i, 4))
	sim.buildings.place("warden_terminal", Vector2i(10, 10), false)
	sim.run_ticks(sim.ticks_per_day + 2)  # informant is picked on a day boundary
	sim.milestones.done_tiers = [0, 1, 2]
	sim.petition.done_phases = [1, 2]
	assert_true(SocietyConds.informant_alive(sim))
	var inf := sim.colonists.get_by_id(sim.blocks.informant_id())
	var b := sim.blocks.block_of(inf)
	var s0 := sim.blocks.standing_of(b)
	var sus0 := sim.contraband.suspicion
	var phases: Array = []
	sim.bus.petition_phase_done.connect(func(p: int) -> void: phases.append(p))
	assert_true(sim.deliver_petition_alt(3, "informant"))
	assert_eq(phases, [3])
	assert_true(sim.contraband.suspicion > sus0)
	assert_true(sim.blocks.standing_of(b) < s0)
	assert_true(sim.milestones.is_tier_done(3))


func test_volunteer_death_keeps_phase_open() -> void:
	var sim := _sim()
	assert_true(sim.deliver_petition_alt(1, "detail"))
	var victim := sim.colonists.get_by_id(sim.petition.detail["ids"][0])
	sim.run_ticks(5)
	sim.colonists.kill(victim)
	sim.run_ticks(3)
	assert_false(sim.petition.detail_active())
	assert_eq(sim.petition.done_phases.size(), 0)
	assert_eq(sim.petition.next_phase(), 1, "phase still open")
	assert_true(sim.petition.alt_available(1) or sim.petition.alt_block_reason(1) != "locked")


func test_save_load_mid_detail() -> void:
	var sim := _sim()
	assert_true(sim.deliver_petition_alt(1, "detail"))
	sim.run_ticks(500)
	assert_true(sim.petition.detail_active())
	# Tier flags are test setup (not commands), so replay by hand: the saved log must carry the command.
	var data := SaveGame.to_dict(sim)
	var logged := false
	for e: Array in data["commands"]:
		logged = logged or (e[1] == "deliver_petition_alt" and e[2] == [1, "detail"])
	assert_true(logged, "command recorded in the save")
	var sim2 := _sim()
	sim2.deliver_petition_alt(1, "detail")
	sim2.run_ticks(500)
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))
	sim.run_ticks(2400)
	sim2.run_ticks(2400)
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))
	assert_eq(sim2.petition.done_phases, sim.petition.done_phases)


func test_deterministic() -> void:
	var hs: Array = []
	for i in 2:
		var sim := _sim(9)
		sim.deliver_petition_alt(1, "detail")
		sim.run_ticks(1500)
		hs.append(SaveGame.state_hash(sim))
	assert_eq(hs[0], hs[1])


func test_panel_alt_row_phone() -> void:
	var sim := _sim()
	var p := PanelRegistry.make_panel("petition")
	_owned_nodes.append(p)
	p.open(sim)
	p.refresh()
	var alt: Button = p.content.find_child("AltButton", true, false)
	assert_true(alt != null, "alt row built")
	assert_true(alt.custom_minimum_size.y >= 64.0 and not alt.disabled)
	alt.pressed.emit()
	assert_true(sim.petition.detail_active())


func test_alt_row_fits_phone_sheet() -> void:
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	host.add_child(game)
	game.sim.defs.balance["e1_enabled"] = true
	game.sim.milestones.done_tiers = [0, 1, 2]
	game.sim.buildings.place("warden_terminal", Vector2i(30, 30), false)
	game.sim.run_ticks(5)
	var root := tree.root
	var old_size := root.size
	var old_scale := root.content_scale_factor
	for sz: Array in [[Vector2i(844, 390), 1.0], [Vector2i(2532, 1170), 2.55]]:
		root.content_scale_factor = sz[1]
		root.size = sz[0]
		game.hud.toggle_panel("petition")
		for i in 4:
			game.hud._process(0.3)
			_sort(game.hud)
		var panel: Node = game.hud._side.find_child("AltButton", true, false)
		assert_true(panel != null, "alt button present at %s" % str(sz[0]))
		if panel != null:
			var r := (panel as Control).get_global_rect()
			var vp := game.hud.get_viewport().get_visible_rect()
			assert_true(r.position.x >= 0.0 and r.end.x <= vp.size.x + 0.5, "alt button within width %s %s" % [str(sz[0]), str(r)])
			assert_true((panel as Control).size.y >= 63.5, "alt button >= 64px tall")
		game.hud.close_side()
	root.size = old_size
	root.content_scale_factor = old_scale


func _sort(n: Node) -> void:
	for ch in n.get_children():
		_sort(ch)
	if n is Container:
		(n as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)
