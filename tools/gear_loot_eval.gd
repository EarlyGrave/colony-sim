extends SceneTree
## F2c: counts creature gear drops under the real factory bot (one process).
## godot --headless --path . -s tools/gear_loot_eval.gd -- [--days=60 --first=1 --seeds=10]
const FBot := preload("res://tools/factory_bot.gd")
const Bot := preload("res://tests/qa_tutorial_bot.gd")


func _init() -> void:
	var days := 60
	var first := 1
	var seeds := 10
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--first="):
			first = int(a.get_slice("=", 1))
		elif a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
	var ok := 0
	for sv in range(first, first + seeds):
		var bus: Node = load("res://autoload/event_bus.gd").new()
		var sim := Simulation.new(sv, bus, null, {"tutorial": true, "research_locked": true})
		sim.start_new_game()
		var bot: RefCounted = FBot.new(sim)
		var limit := days * sim.ticks_per_day
		while sim.tick < limit and sim.game_over_reason == "":
			bot.act()
			for qp in sim.quests.pending.duplicate():
				for qo: Dictionary in qp["options"]:
					if bool(qo["enabled"]):
						sim.answer_quest(int(qp["uid"]), str(qo["id"]))
						break
			sim.run_ticks(Bot.STEP_TICKS)
			bot.after()
		var by_rarity := {}
		for id: int in sim.equipment.instances:
			var r: String = sim.equipment.instances[id].rarity
			by_rarity[r] = int(by_rarity.get(r, 0)) + 1
		var n: int = sim.equipment.instances.size()
		ok += 1 if n >= 3 else 0
		print("seed %d drops=%d kills=%d waves=%d day=%d alive=%d pol=%.0f%% %s" % [sv, n, sim.threats.kills, sim.threats.wave_index, sim.day(), sim.colonists.alive_count(), sim.contamination.fraction() * 100.0, str(by_rarity)])
		bus.free()
	print("seeds with >=3 drops: %d/%d" % [ok, seeds])
	quit()
