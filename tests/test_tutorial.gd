extends TestCase
## Warden's Orientation engine (R5 O1): 12 steps, skip commands, scripted raid, determinism.

const Scen := preload("res://tests/scenario.gd")


func _tut_sim(seed_value := 1, defs: Defs = null) -> Simulation:
	var sim := Simulation.new(seed_value, make_bus(), defs, {"tutorial": true})
	sim.start_new_game()
	_sims.append(sim)
	return sim


func _skip_to(sim: Simulation, id: String) -> void:
	var guard := 0
	while not sim.tutorial.finished() and str(sim.tutorial.current()["id"]) != id and guard < 20:
		sim.tutorial_skip_step()
		guard += 1


func test_off_by_default() -> void:
	var sim := make_sim(1)
	assert_true(sim.tutorial == null, "no tutorial without opts.tutorial")
	var h := SaveGame.state_hash(sim)
	var n0 := sim.command_log.size()
	sim.tutorial_ack()
	sim.tutorial_skip_step()
	sim.tutorial_skip_all()
	assert_eq(SaveGame.state_hash(sim), h, "tutorial commands are no-ops without the tutorial")
	assert_eq(sim.command_log.size() - n0, 3, "but they are still recorded")


func test_data_has_twelve_steps() -> void:
	var sim := _tut_sim()
	assert_eq(sim.tutorial.step_count(), 12)
	var ids := {}
	for s: Dictionary in sim.tutorial.steps:
		assert_true(not ids.has(s["id"]), "unique id")
		ids[s["id"]] = true
		for k in ["title", "text", "reason", "target", "done", "nudge_ticks"]:
			assert_true(s.has(k), "%s has %s" % [s["id"], k])
	assert_eq(sim.tutorial.audit_index, 9)
	assert_eq(sim.tutorial.step, 0)
	assert_false(sim.tutorial.finished())


func test_twelve_steps_advance_only_on_their_signal() -> void:
	var sim := _tut_sim(1)
	var t := sim.tutorial
	var center := sim.map_center()
	# 1 intake: only the ack command
	sim.run_ticks(20)
	sim.set_alarm(false)
	assert_eq(t.step, 0, "ticks and other commands do not advance intake")
	sim.tutorial_ack()
	assert_eq(t.step, 1, "step 1 ack")
	# 2 dig: three distinct designations
	sim.set_zone(center + Vector2i(8, 8), "")
	assert_eq(t.step, 1, "unrelated command")
	Scen.designate_nearest_deposits(sim, 2)
	assert_eq(t.step, 1, "2 of 3 designations")
	Scen.designate_nearest_deposits(sim, 3)
	assert_eq(t.step, 2, "step 2 three designations")
	# 3 storage: four zone cells
	var o := Scen.find_zone_spot(sim, center + Vector2i(-8, 4), Vector2i(2, 2))
	sim.set_zone(o, "stockpile")
	sim.set_zone(o + Vector2i(1, 0), "stockpile")
	sim.set_zone(o + Vector2i(0, 1), "stockpile")
	assert_eq(t.step, 2, "3 of 4 zone cells")
	sim.set_zone(o + Vector2i(1, 1), "stockpile")
	assert_eq(t.step, 3, "step 3 four zone cells")
	# 4 haul: mined signal alone is not enough, stock must lie in storage
	sim.bus.item_mined.emit(center, "essence_ore", 1)
	assert_eq(t.step, 3, "mined signal without stock")
	var have := sim.items.count_stored("essence_ore")
	var room := o
	sim.ledger.record_produced("essence_ore", 10, "test")
	sim.items.add_at(room, "essence_ore", 10)
	assert_gt(sim.items.count_stored("essence_ore"), have + 9)
	sim.run_ticks(1)
	assert_eq(t.step, 4, "step 4 stock >= 10")
	# 5 tool: a wall does not count, a workbench does
	var w := Scen.find_spot(sim, "wall", center + Vector2i(6, 6), 0)
	sim.place_instant("wall", w)
	assert_eq(t.step, 4, "wall is not a first tool")
	sim.place_instant("workbench", Scen.find_spot(sim, "workbench", center + Vector2i(-6, -6), 0))
	assert_eq(t.step, 5, "step 5 workbench")
	# 6 dirty hands
	sim.bus.first_refine_done.emit()
	assert_eq(t.step, 6, "step 6 first refine")
	# 7 research
	sim.run_ticks(5)
	assert_eq(t.step, 6, "no drift")
	sim.bus.research_completed.emit("anything")
	assert_eq(t.step, 7, "step 7 research")
	# 8 belt: three belt cells alone are not enough, an item must reach a port building
	var bs := Scen.find_spot(sim, "storage_in", center + Vector2i(-10, -10), 3)
	var sb := sim.place_instant("storage_in", bs)
	assert_true(sb != null, "storage_in placed")
	var cells: Array = []
	for i in 3:
		cells.append(bs + Vector2i(-3 + i, 0))
	sim.place_belt(cells, 1)
	sim.run_ticks(3)
	assert_eq(t.step, 7, "belts without a delivery")
	sb.output["essence_ore"] = 1
	sim.run_ticks(2)
	assert_eq(t.step, 8, "step 8 belt delivery")
	# 9 forecast
	sim.run_ticks(5)
	assert_eq(t.step, 8, "forecast waits")
	sim.bus.forecast_revealed.emit()
	assert_eq(t.step, 9, "step 9 forecast")
	# 10 audit: scripted raid; alarm raised by the player, then repelled
	assert_true(sim.threats.awakened, "audit arms the threat system")
	sim.set_alarm(true)
	var guard := 0
	while t.step == 9 and guard < 6000:
		sim.step()
		guard += 1
	assert_eq(t.step, 10, "step 10 audit repelled (ticks %d)" % guard)
	assert_eq(sim.threats.wave_index, 1)
	# 11 decoy
	sim.run_ticks(3)
	assert_eq(t.step, 10, "decoy waits")
	sim.place_instant("ash_beacon", Scen.find_spot(sim, "ash_beacon", center + Vector2i(9, 0), 2))
	assert_eq(t.step, 11, "step 11 decoy placed")
	# 12 release
	sim.tutorial_ack()
	assert_true(t.finished(), "step 12 release")
	assert_eq(t.done.size(), 12)
	assert_false(t.skipped)


func test_decoy_step_also_ends_at_next_wave_warning() -> void:
	var sim := _tut_sim(2)
	_skip_to(sim, "decoy")
	assert_eq(str(sim.tutorial.current()["id"]), "decoy")
	sim.bus.wave_incoming.emit(Vector2i(0, 0), 100)
	assert_eq(str(sim.tutorial.current()["id"]), "release")


func test_forecast_step_accepts_ack() -> void:
	var sim := _tut_sim(2)
	_skip_to(sim, "forecast")
	sim.tutorial_ack()
	assert_eq(str(sim.tutorial.current()["id"]), "audit")


func test_skip_all_finishes_within_a_tick() -> void:
	var sim := _tut_sim(3)
	var fired := [0]
	sim.bus.tutorial_finished.connect(func() -> void: fired[0] += 1)
	sim.tutorial_skip_all()
	assert_eq(sim.tutorial.step, 12)
	assert_true(sim.tutorial.finished())
	assert_true(sim.tutorial.skipped)
	assert_eq(sim.tutorial.done.size(), 12)
	assert_eq(fired[0], 1)
	sim.step()
	assert_eq(sim.tutorial.step, 12)
	assert_false(sim.tutorial.waves_held())
	sim.tutorial_skip_all()
	assert_eq(fired[0], 1, "finish signalled once")


func test_skip_step_is_recorded_and_one_at_a_time() -> void:
	var sim := _tut_sim(3)
	var n0 := sim.command_log.size()
	sim.tutorial_skip_step()
	assert_eq(sim.tutorial.step, 1)
	assert_eq(sim.tutorial.done, ["intake"] as Array[String])
	assert_eq(sim.command_log.size() - n0, 1)
	assert_eq(sim.command_log[-1][1], "tutorial_skip_step")


func test_nudge_after_idle_ticks() -> void:
	var sim := _tut_sim(3)
	assert_false(sim.tutorial.nudge_due())
	sim.run_ticks(int(sim.tutorial.current()["nudge_ticks"]))
	assert_true(sim.tutorial.nudge_due())
	sim.tutorial_skip_step()
	assert_false(sim.tutorial.nudge_due(), "new step resets the idle clock")


func test_normal_waves_held_until_audit() -> void:
	var sim := _tut_sim(4)
	sim.threats.awaken()
	sim.run_ticks(sim.threats.next_wave_tick - sim.tick + 400)
	assert_eq(sim.threats.wave_index, 0, "no wave before the audit step")
	_skip_to(sim, "audit")
	var guard := 0
	while sim.threats.wave_index == 0 and guard < 1000:
		sim.step()
		guard += 1
	assert_eq(sim.threats.wave_index, 1, "audit wave comes soon after the step starts")
	assert_eq(sim.threats.force_raid_id, "", "force flag consumed")


func test_audit_raid_cannot_hurt_pod_or_inmates() -> void:
	for s in range(1, 21):
		var sim := _tut_sim(s)
		var hq: Building = null
		for b in sim.buildings.list:
			if b.def_id == "hq":
				hq = b
		var hp0 := hq.hp
		_skip_to(sim, "audit")
		var saw_raid := false
		for i in 2400:
			sim.step()
			if sim.threats.raid_id == "tutorial_audit":
				saw_raid = true
				assert_eq(sim.threats.raid_total, 2)
				assert_eq(hq.hp, hp0, "pod hp seed %d tick %d" % [s, sim.tick])
		assert_true(saw_raid, "audit raid ran for seed %d" % s)
		assert_eq(sim.game_over_reason, "", "seed %d" % s)
		for c in sim.colonists.list:
			assert_true(c.alive, "inmate alive seed %d" % s)
		assert_eq(sim.threats.wave_index, 1)
		assert_false(sim.threats.wave_active, "audit ended, seed %d" % s)


func test_replay_of_recorded_tutorial_commands_is_equal() -> void:
	var sim := _tut_sim(5)
	sim.run_ticks(30)
	sim.tutorial_ack()
	Scen.designate_nearest_deposits(sim, 3)
	sim.run_ticks(40)
	sim.tutorial_skip_step()
	sim.run_ticks(25)
	sim.tutorial_skip_step()
	sim.run_ticks(300)
	var h := SaveGame.state_hash(sim)
	var data := SaveGame.to_dict(sim)
	for i in 2:
		var res := SaveGame.load_dict(data, make_bus())
		assert_true(res["ok"], str(res["error"]))
		var rs: Simulation = res["sim"]
		_sims.append(rs)
		assert_eq(SaveGame.state_hash(rs), h, "replay %d state_hash" % i)
		assert_eq(rs.tutorial.step, sim.tutorial.step)
		assert_eq(rs.tutorial.done, sim.tutorial.done)


func test_tutorial_hash_part_only_in_tutorial_mode() -> void:
	var a := make_sim(7)
	var b := _tut_sim(7)
	a.run_ticks(10)
	b.run_ticks(10)
	assert_ne(SaveGame.state_hash(a), SaveGame.state_hash(b))
	assert_true(a.tutorial == null)
