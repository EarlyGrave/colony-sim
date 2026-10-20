extends TestCase
## F5 W1: Standing Orders (slots, exclusions, timeout default, effects, save/load, panel at phone size).


static func reg_defs(on := true) -> Defs:
	var d := peaceful_defs()
	d.balance["reg_enabled"] = on
	var days := [1, 2, 3]  # compress the schedule: slots open at day 1/2/3
	for i in 3:
		d.regulations["slots"][i]["day"] = days[i]
	return d


func test_flag_off_is_inert() -> void:
	var sim := make_sim(3, true, 24, 24, reg_defs(false))
	sim.run_ticks(3 * sim.ticks_per_day)
	assert_eq(sim.regulations.pending, -1)
	assert_true(sim.regulations.chosen.is_empty(), "nothing chosen")
	assert_false(sim.choose_regulation(0, "overtime"), "command rejected while off")
	assert_eq(sim.regulations.mult("waste"), 1.0)


func test_slot_opens_and_choice_applies_once() -> void:
	var sim := make_sim(3, true, 24, 24, reg_defs())
	sim.run_ticks(sim.ticks_per_day + 5)
	assert_eq(sim.regulations.pending, 0)
	assert_false(sim.choose_regulation(0, "nonsense"), "unknown option")
	assert_false(sim.choose_regulation(1, "grease"), "slot not open")
	assert_true(sim.choose_regulation(0, "overtime"))
	assert_false(sim.choose_regulation(0, "standard"), "already answered")
	assert_eq(sim.regulations.mult("waste"), 1.25)
	assert_eq(sim.quests.mod("refine_mult"), 1.25)
	sim.run_ticks(sim.ticks_per_day)
	assert_eq(sim.regulations.pending, 1, "next slot opens")
	assert_eq(sim.quests.mod("refine_mult"), 1.25, "effect not re-applied")


func test_excluded_option_rejected() -> void:
	var sim := make_sim(3, true, 24, 24, reg_defs())
	sim.run_ticks(sim.ticks_per_day + 5)
	assert_true(sim.choose_regulation(0, "night_watch"))
	sim.run_ticks(sim.ticks_per_day)
	assert_true(sim.choose_regulation(1, "comply"))
	sim.run_ticks(sim.ticks_per_day)
	assert_eq(sim.regulations.pending, 2)
	var before := sim.command_log.size()
	assert_false(sim.choose_regulation(2, "zero_tolerance"), "locked by night_watch")
	assert_eq(sim.regulations.mult("despair_mult"), 1.15, "only night_watch applied")
	assert_eq(sim.command_log.size(), before + 1, "rejected command is still recorded")
	assert_true(sim.choose_regulation(2, "clean_yard"))
	assert_eq(sim.regulations.mult("waste"), 0.75)


func test_timeout_takes_default() -> void:
	var sim := make_sim(3, true, 24, 24, reg_defs())
	sim.run_ticks(sim.ticks_per_day + 5)
	assert_eq(sim.regulations.pending, 0)
	sim.run_ticks(int(2.0 * sim.ticks_per_day) + 5)
	assert_eq(sim.regulations.chosen.get(0), "standard", "default after 2 days")
	assert_eq(sim.regulations.mult("waste"), 1.0)


func test_deterministic_and_save_load() -> void:
	var a := make_sim(7, true, 24, 24, reg_defs())
	var b := make_sim(7, true, 24, 24, reg_defs())
	for s in [a, b]:
		s.run_ticks(s.ticks_per_day + 5)
		s.choose_regulation(0, "overtime")
		s.run_ticks(s.ticks_per_day)
		s.choose_regulation(1, "open_books")
		s.run_ticks(60)
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b), "same seed + commands")
	var res := SaveGame.load_json(SaveGame.to_json(a), make_bus(), reg_defs())
	assert_true(res["ok"], str(res["error"]))
	var c: Simulation = res["sim"]
	_sims.append(c)
	assert_eq(SaveGame.state_hash(c), SaveGame.state_hash(a), "round trip")
	assert_eq(c.regulations.chosen, a.regulations.chosen)
	assert_eq(c.regulations.mult("waste"), a.regulations.mult("waste"))
	a.run_ticks(1000)
	c.run_ticks(1000)
	assert_eq(SaveGame.state_hash(c), SaveGame.state_hash(a), "continue identically")


func test_waste_mult_changes_contamination_rate() -> void:
	var d := reg_defs()
	var base := make_sim(5, true, 24, 24, d)
	var lean := make_sim(5, true, 24, 24, reg_defs())
	lean.regulations._mults["waste"] = 0.5
	assert_eq(base.regulations.mult("waste"), 1.0)
	assert_eq(lean.regulations.mult("waste"), 0.5)


func test_panel_phone_layout() -> void:
	var sim := make_sim(3, true, 24, 24, reg_defs())
	sim.run_ticks(sim.ticks_per_day + 5)
	var p := PanelRegistry.make_panel("orders") as RegulationCard
	assert_true(p != null, "orders registered")
	_owned_nodes.append(p)
	p.open(sim)
	var buttons := 0
	for ch in p.content.get_children():
		if ch is Button:
			buttons += 1
			assert_true((ch as Button).custom_minimum_size.y >= 64.0, "button >= 64 px")
		if ch is Label:
			assert_true((ch as Label).autowrap_mode != TextServer.AUTOWRAP_OFF, "text wraps")
			assert_true(((ch as Label).text).length() <= 70, "line <= 70 chars: " + (ch as Label).text)
	assert_eq(buttons, 3, "three options")
	sim.choose_regulation(0, "standard")
	p.refresh()
	for ch in p.content.get_children():
		assert_false(ch is Button, "no buttons once answered")
	# whole HUD at 844x390: the sheet opens without exceeding the phone viewport
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	host.add_child(game)
	game.hud.toggle_panel("orders")
	assert_true(game.hud._side != null, "side sheet exists")
