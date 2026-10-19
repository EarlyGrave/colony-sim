extends SceneTree
## S5: shuttle bot (petition_bot + sustain + shuttle steps). Assumed S1 API (skipped when absent): Simulation.get_shuttle_state() {phase,parts,need,t_left,hp}, launch_shuttle(), balance key s1_enabled, building "release_gantry", items "release_part" supplied by script like petition supply. Sustain: --throttle=1 (default) turns on the refine_cap rule; --throttle=0 shows the old failure.
## E1: petition bot. Runs the tutorial bot + bot_report upkeep with e1_enabled on and delivers the
## Sentence Commutation Petition. The bot has no real factory: parts/ingots/coal/nitrogen/essence
## arrive as a scripted per-day trickle (ASSUMED output of a modest base), so the table measures
## the petition's pacing and plumbing, not production balance.
## godot --headless --path . -s tools/petition_bot.gd [-- --days=40 --seeds=5]
const Bot := preload("res://tests/qa_tutorial_bot.gd")
const BotReport := preload("res://tools/bot_report.gd")
const Scenario := preload("res://tests/scenario.gd")
## item -> [first_day, per_day]
const SUPPLY := {"plate": [1, 9], "parts": [1, 3], "ingot_iron": [6, 4], "ingot_copper": [6, 4],
	"fuel_cell": [20, 3], "coal": [10, 4], "nitrogen": [10, 3], "refined_essence": [20, 7]}  # fuel_cell = scripted output of nitrogen + plate at the workbench


## Free instant placement at the nearest valid spot (the bot has no builders for these).
func _place_near(sim: Simulation, id: String, near: Vector2i) -> Building:
	return sim.buildings.place(id, Scenario.find_spot(sim, id, near, 0), false)


## Gantry + power (2 solar arrays and a pole) + defensive turrets around it.
func _build_site(sim: Simulation, center: Vector2i) -> void:
	var g := _place_near(sim, "release_gantry", center + Vector2i(-12, -8))
	if g == null:
		return
	var o := g.cell
	_place_near(sim, "power_pole", o + Vector2i(4, 1))
	for i in 3:
		_place_near(sim, "solar_array", o + Vector2i(5 + i * 2, 3))
	if "--turrets=0" in OS.get_cmdline_user_args():
		return
	for off in [Vector2i(-2, -2), Vector2i(5, -2), Vector2i(-2, 5), Vector2i(5, 5), Vector2i(2, -3), Vector2i(2, 6)]:
		_place_near(sim, "turret", o + off)


func _init() -> void:
	var days := 40
	var seeds := 5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
	var throttle := 1
	var cap := 50
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--throttle="):
			throttle = int(a.get_slice("=", 1))
		elif a.begins_with("--cap="):
			cap = int(a.get_slice("=", 1))
	var reach := [0, 0, 0, 0]
	var launches := 0
	var wins := 0
	var first := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--first="):
			first = int(a.get_slice("=", 1))
	for sv in range(first, first + seeds):
		var bus: Node = load("res://autoload/event_bus.gd").new()
		var defs := Defs.get_default().duplicate_defs()
		defs.balance["e1_enabled"] = true
		for k in ["s1_enabled", "s2_enabled"]:
			defs.balance[k] = true
		var sim := Simulation.new(sv, bus, defs, {"tutorial": true, "research_locked": true})
		sim.start_new_game()
		var bot := Bot.new(sim)
		var r := {"turrets_rebuilt": 0}
		var center := sim.map_center()
		for y in 3:
			for x in 4:
				sim.set_zone(center + Vector2i(5 + x, 6 + y), "stockpile")
		sim.buildings.place("warden_terminal", Scenario.find_spot(sim, "warden_terminal", center + Vector2i(5, 3), 0), false)
		if throttle == 1:
			if not sim.research.done.has("filters"):
				sim.research.done.append("filters")
			sim.defs.rules["refine_cap"]["max_contamination_percent"] = cap
			sim.set_rule("refine_cap", true)
		var launch_day := "-"
		var outcome := "-"
		var when: Array = ["-", "-", "-", "-"]
		var supplied_day := 0
		var fails_seen := 0
		var min_hp := 100
		var limit := days * sim.ticks_per_day
		while sim.tick < limit and sim.game_over_reason == "":
			bot._act()
			if bot.complete():
				BotReport._act(sim, 3, r)
			var d := sim.day()
			if "--trace" in OS.get_cmdline_user_args() and sim.tick % sim.ticks_per_day == 0:
				print("  d%d pol%%=%.0f food=%d meal=%d ore=%d refined=%d waste=%.0f cols=%d waves=%d" % [d, sim.contamination.fraction() * 100.0, sim.items.count_stored("raw_food"), sim.items.count_stored("meal"), sim.items.count_stored("essence_ore"), sim.items.count_stored("refined_essence"), sim.contamination.waste_units(), sim.colonists.alive_count(), sim.threats.wave_index])
			while supplied_day < d:
				supplied_day += 1
				for item: String in SUPPLY:
					if supplied_day >= int(SUPPLY[item][0]) and sim.defs.items.has(item):
						sim.ledger.record_produced(item, int(SUPPLY[item][1]), "bot_supply")
						sim.items.drop(center + Vector2i(5, 6), item, int(SUPPLY[item][1]))
			if sim.tick % 600 == 0:
				if not sim.milestones.is_tier_done(2):
					sim.deliver_audit(2)
				else:
					var p: int = sim.petition.next_phase()
					if p > 0 and sim.deliver_petition(p):
						when[p - 1] = "%.1f" % (float(sim.tick) / float(sim.ticks_per_day))
						reach[p - 1] += 1
			if sim.tick % 100 == 0:
				var st: Dictionary = sim.get_shuttle_state()
				var ph := str(st.get("phase", ""))
				if ph == "building" or ph == "ready":
					if sim.shuttle.gantry() == null:
						_build_site(sim, center)
					if sim.tick % 600 == 0:
						sim.deliver_shuttle_parts()
				if ph == "ready" and sim.launch_shuttle():
					launch_day = "%.1f" % (float(sim.tick) / float(sim.ticks_per_day))
					launches += 1
					if sim.shuttle.launches > 1:
						launch_day += "(retry)"
				if ph == "countdown":
					min_hp = mini(min_hp, int(st["hp"]) * 100 / maxi(1, int(st["max_hp"])))
				if ph == "countdown" and int(st["hp"]) < int(st["max_hp"]) * 7 / 10:
					sim.repair_gantry()
				if ph == "won" and outcome != "won":
					outcome = "won"
					wins += 1
				if int(st.get("failures", 0)) > fails_seen:
					fails_seen = int(st["failures"])
					outcome = "fail x%d" % fails_seen
				if sim.beacons.enabled() and sim.tick % 600 == 0 and ph != "locked" and sim.buildings.count_of("beacon_launcher") == 0:
					_place_near(sim, "beacon_launcher", center + Vector2i(-8, 8))
					_place_near(sim, "power_pole", center + Vector2i(-6, 8))
					_place_near(sim, "solar_array", center + Vector2i(-4, 10))
			sim.run_ticks(Bot.STEP_TICKS)
			bot._poll()
		var bs: Dictionary = sim.get_beacon_state()
		print("seed %d P1..P4 day=%s tier=%d launch=%s outcome=%s pol%%=%.0f over=%s end_day=%d debt%%=%.0f beacons launched=%d cut=%d cols=%d min_hp%%=%d" % [sv, ",".join(when), sim.milestones.tier(), launch_day, outcome, sim.contamination.fraction() * 100.0, sim.game_over_reason, sim.day(), sim.milestones.debt_paid_pct(), int(bs["launched"]), int(bs["total_cut"]), sim.colonists.alive_count(), min_hp])
		sim.dispose()
		bus.free()
	print("reach P1..P4 over %d seeds: %s" % [seeds, str(reach)] + " launches=%d wins=%d" % [launches, wins])
	quit()
