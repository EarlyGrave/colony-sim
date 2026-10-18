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
	var ok_seeds := 0
	for sv in range(1, seeds + 1):
		var bus: Node = load("res://autoload/event_bus.gd").new()
		var sim := Bot.make_sim(sv, bus)
		var bot := Bot.new(sim)
		var r := {"turrets_rebuilt": 0}
		var when: Array = []
		var seen := 0
		var limit := days * sim.ticks_per_day
		while sim.tick < limit and sim.game_over_reason == "":
			bot._act()
			if bot.complete():
				BotReport._act(sim, 3, r)
			sim.run_ticks(Bot.STEP_TICKS)
			bot._poll()
			var n := sim.milestones.reviews_done.size()
			while seen < n:
				when.append("%.1f" % (float(sim.tick) / float(sim.ticks_per_day)))
				seen += 1
		if seen >= 3:
			ok_seeds += 1
		print("seed %d tut=%s reviews=%d at_days=%s end_day=%d over=%s waves=%d debt%%=%.0f tier=%d" % [sv, bot.complete(), seen, ",".join(when), sim.day(), sim.game_over_reason, sim.milestones.waves_repelled, sim.milestones.debt_paid_pct(), sim.milestones.tier()])
		sim.dispose()
		bus.free()
	print("seeds with 3 reviews: %d/%d" % [ok_seeds, seeds])
	quit()
