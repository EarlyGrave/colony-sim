extends SceneTree
const Bot := preload("res://tests/qa_tutorial_bot.gd")
## OS: colonist health probe. godot --headless --path . -s tools/os_diag.gd -- --seed=9 --from=30 --to=40
func _init() -> void:
	var sd := 9
	var d0 := 30
	var d1 := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			sd = int(a.get_slice("=", 1))
		if a.begins_with("--from="):
			d0 = int(a.get_slice("=", 1))
		if a.begins_with("--to="):
			d1 = int(a.get_slice("=", 1))
	var bus = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(sd, bus, null, {"tutorial": true, "research_locked": true})
	sim.start_new_game()
	var bot = (load("res://tools/factory_bot.gd") as GDScript).new(sim)
	bot.cap_percent = 35
	bot.plate_target = 45
	var lim := d1 * sim.ticks_per_day
	while sim.tick < lim and sim.game_over_reason == "":
		bot.act()
		sim.run_ticks(Bot.STEP_TICKS)
		bot.after()
		if sim.tick >= d0 * sim.ticks_per_day and sim.tick % 100 < Bot.STEP_TICKS:
			var s := "d%.2f alarm=%s night=%s hid=%d food0=%.2f alive=%d food=%d |" % [float(sim.tick) / sim.ticks_per_day, str(sim.alarm), str(sim.clock.is_night()), sim.colonists.list.filter(func(q): return q.alive and q.hidden).size(), sim.needs.state_of(sim.colonists.list[0]).food, sim.colonists.alive_count(), sim.items.count_stored("raw_food") + sim.items.count_stored("meal")]
			for c in sim.colonists.list:
				if not c.alive:
					continue
				var h = sim.health.state_of(c)
				var cnt := {}
				for i in h.injuries:
					var kk: String = i.illness_id if i.is_illness() else i.kind
					cnt[kk] = int(cnt.get(kk, 0)) + 1
				var inj := str(cnt)
				s += " [%d %s blood=%.2f %s%s%s]" % [c.id, c.job.type if c.job != null else "-", h.blood, "DOWN " if h.downed else "", "bed%d " % h.bed_id if h.bed_id >= 0 else "", inj]
			print(s)
	quit()
