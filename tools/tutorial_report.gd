extends SceneTree
## Prints days per tutorial goal for seeds 1..3:
## godot --headless --path . -s tools/tutorial_report.gd

const Bot := preload("res://tests/qa_tutorial_bot.gd")


func _init() -> void:
	for seed_value in [1, 2, 3]:
		var bus: Node = preload("res://autoload/event_bus.gd").new()
		var sim := Bot.make_sim(seed_value, bus)
		var bot := Bot.new(sim)
		bot.run(int(OS.get_environment("DAYS")) if OS.get_environment("DAYS") != "" else 12)
		var row := []
		for g in Bot.GOALS:
			row.append("%s=%.1f" % [g, bot.days_for(g)])
		print("seed %d complete=%s dead=%d over=%s %s" % [seed_value, bot.complete(), sim.colonists.list.filter(func(c: Colonist) -> bool: return not c.alive).size(), sim.game_over_reason, " ".join(row)])
		sim.dispose()
		bus.free()
	quit()
