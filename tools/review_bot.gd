extends SceneTree
## BX: tutorial bot finishes Warden's Orientation, then plays free (tutorial bot upkeep + bot_report
## contract/debt/turret logic) up to --days; prints the day each Parole Review was passed.
## godot --headless --path . -s tools/review_bot.gd [-- --days=25 --seeds=5]
const Bot := preload("res://tests/qa_tutorial_bot.gd")
const BotReport := preload("res://tools/bot_report.gd")


func _init() -> void:
	var days := 25
	var seeds := 5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
	var e3 := false
	var rich := false  # QA aid: a flush player at day 14 pays all debts (the plain bot cannot refine enough)
	var profile := ""
	for a in OS.get_cmdline_user_args():
		if a == "--rich":
			rich = true
		elif a == "--e3":
			e3 = true
		elif a.begins_with("--profile="):
			profile = a.get_slice("=", 1)
	var ok_seeds := 0
	var e3_ok := [0, 0]
	for sv in range(1, seeds + 1):
		var bus: Node = load("res://autoload/event_bus.gd").new()
		var sim := Bot.make_sim(sv, bus)
		sim.defs.balance["e3_enabled"] = e3  # region E3
		var best_rs := 0.0
		var bot := Bot.new(sim)
		var r := {"turrets_rebuilt": 0}
		var when: Array = []
		var seen := 0
		var limit := days * sim.ticks_per_day
		while sim.tick < limit and sim.game_over_reason == "":
			bot._act()
			if rich and sim.tick == 14 * sim.ticks_per_day:
				sim.items.drop(sim.map_center(), "refined_essence", 600)
			if rich and sim.tick > 14 * sim.ticks_per_day and sim.tick % sim.ticks_per_day == 0:
				for c in sim.colonists.list:
					sim.debt.pay(c, 999)
			if bot.complete():
				BotReport._act(sim, 3, r)
				best_rs = maxf(best_rs, sim.milestones.e3_range_score())  # region E3
			sim.run_ticks(Bot.STEP_TICKS)
			bot._poll()
			var n := sim.milestones.reviews_done.size()
			while seen < n:
				when.append("%.1f" % (float(sim.tick) / float(sim.ticks_per_day)))
				seen += 1
		if sim.milestones.reviews_done.has("e3_review_4"):
			e3_ok[0] += 1
		if sim.milestones.reviews_done.has("e3_review_5"):
			e3_ok[1] += 1
		if e3:
			print("  E3 seed %d: R4=%s R5=%s best_range=%.1f debt_left=%.1f%% rank=%s" % [sv, sim.milestones.reviews_done.has("e3_review_4"), sim.milestones.reviews_done.has("e3_review_5"), best_rs, 100.0 - sim.milestones.debt_paid_pct(), sim.milestones.e3_rank_title()])
		if seen >= 3:
			ok_seeds += 1
		print("seed %d tut=%s reviews=%d at_days=%s end_day=%d over=%s waves=%d debt%%=%.0f tier=%d" % [sv, bot.complete(), seen, ",".join(when), sim.day(), sim.game_over_reason, sim.milestones.waves_repelled, sim.milestones.debt_paid_pct(), sim.milestones.tier()])
		sim.dispose()
		bus.free()
	print("seeds with 3 reviews: %d/%d" % [ok_seeds, seeds])
	if e3:
		print("E3 R4 %d/%d R5 %d/%d" % [e3_ok[0], seeds, e3_ok[1], seeds])
	quit()
