extends SceneTree
const Bot := preload("res://tests/qa_tutorial_bot.gd")
## LA: shuttle-gap probe. godot --headless --path . -s tools/la_diag.gd -- --seed=6 --days=60 [--cu]
func _init() -> void:
	var sd := 6
	var days := 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			sd = int(a.get_slice("=", 1))
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
	var bus = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(sd, bus, null, {"tutorial": true, "research_locked": true})
	sim.start_new_game()
	var bot = (load("res://tools/factory_bot.gd") as GDScript).new(sim)
	bot.cap_percent = 35
	bot.plate_target = 45
	var lim := days * sim.ticks_per_day
	while sim.tick < lim and sim.game_over_reason == "":
		bot.act()
		sim.run_ticks(Bot.STEP_TICKS)
		bot.after()
		if sim.tick % (sim.ticks_per_day * 5) < Bot.STEP_TICKS:
			print("d", sim.day(), " ", sim.get_shuttle_state(), " phases=", sim.petition.done_phases.size(), " ref=", sim.items.count_stored("refined_essence"), " plate=", sim.items.count_stored("plate"), " alive=", sim.colonists.alive_count())
	print("END ", sim.get_shuttle_state(), " gantry=", sim.shuttle.gantry() != null)
	quit()
