extends SceneTree
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
	"coal": [10, 4], "nitrogen": [10, 3], "refined_essence": [20, 5]}


func _init() -> void:
	var days := 40
	var seeds := 5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
	var reach := [0, 0, 0, 0]
	for sv in range(1, seeds + 1):
		var bus: Node = load("res://autoload/event_bus.gd").new()
		var defs := Defs.get_default().duplicate_defs()
		defs.balance["e1_enabled"] = true
		var sim := Simulation.new(sv, bus, defs, {"tutorial": true, "research_locked": true})
		sim.start_new_game()
		var bot := Bot.new(sim)
		var r := {"turrets_rebuilt": 0}
		var center := sim.map_center()
		for y in 3:
			for x in 4:
				sim.set_zone(center + Vector2i(5 + x, 6 + y), "stockpile")
		sim.buildings.place("warden_terminal", Scenario.find_spot(sim, "warden_terminal", center + Vector2i(5, 3), 0), false)
		var when: Array = ["-", "-", "-", "-"]
		var supplied_day := 0
		var limit := days * sim.ticks_per_day
		while sim.tick < limit and sim.game_over_reason == "":
			bot._act()
			if bot.complete():
				BotReport._act(sim, 3, r)
			var d := sim.day()
			while supplied_day < d:
				supplied_day += 1
				for item: String in SUPPLY:
					if supplied_day >= int(SUPPLY[item][0]):
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
			sim.run_ticks(Bot.STEP_TICKS)
			bot._poll()
		print("seed %d P1..P4 day=%s tier=%d over=%s end_day=%d debt%%=%.0f" % [sv, ",".join(when), sim.milestones.tier(), sim.game_over_reason, sim.day(), sim.milestones.debt_paid_pct()])
		sim.dispose()
		bus.free()
	print("reach P1..P4 over %d seeds: %s" % [seeds, str(reach)])
	quit()
