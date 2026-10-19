extends SceneTree
## YX: debug dump of machine states after N days. -- --seed=2 --days=40 --plate=45 --ovf=<json file>
const Report := preload("res://tools/factory_bot_report.gd")
const Bot := preload("res://tests/qa_tutorial_bot.gd")


func _init() -> void:
	var seed_v := 2
	var days := 40
	var plate := 8
	var verbose := "--v" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_v = int(a.get_slice("=", 1))
		elif a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--plate="):
			plate = int(a.get_slice("=", 1))
		elif a.begins_with("--ovf="):
			Report.apply_overrides(Defs.get_default(), JSON.parse_string(FileAccess.get_file_as_string(a.substr(6))))
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(seed_v, bus, null, {"tutorial": true, "research_locked": true})
	sim.start_new_game()
	var bot: RefCounted = (load("res://tools/factory_bot.gd") as GDScript).new(sim)
	bot.plate_target = plate
	var limit := days * sim.ticks_per_day
	while sim.tick < limit and sim.game_over_reason == "":
		bot.act()
		sim.run_ticks(Bot.STEP_TICKS)
		bot.after()
		if sim.tick % (sim.ticks_per_day * 3) == 0 and verbose:
			print("d%d ore=%d ref=%d plate=%d step=%d bps=%d alive=%d pol=%.0f%% res=%s q=%s" % [sim.day(), sim.items.count_stored("essence_ore"), sim.items.count_stored("refined_essence"), sim.items.count_stored("plate"), bot._step, sim.buildings.blueprints.size(), sim.colonists.alive_count(), sim.contamination.fraction() * 100.0, str(sim.research.done), str(sim.research.queue)])
	print("day ", sim.day(), " over=", sim.game_over_reason, " alive=", sim.colonists.alive_count())
	for b in sim.buildings.list:
		if b.def_id in ["miner", "smelter", "assembler", "refinery", "storage_in", "workbench"]:
			print(b.def_id, b.cell, " in=", b.input, " out=", b.output, " rec=", b.recipe_id, " broken=", b.broken, " cond=%.0f" % b.condition, " net=", b.power_net, " prog=", b.progress)
	var srcs := []
	for k: String in sim.ledger.by_source:
		if k.ends_with(":essence_ore"):
			srcs.append("%s=%d" % [k, sim.ledger.by_source[k]])
	print("ore sources: ", ", ".join(srcs))
	for l: String in bot.log:
		print("  ", l)
	quit()
