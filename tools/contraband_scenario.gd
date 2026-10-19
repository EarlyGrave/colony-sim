extends SceneTree
## CD: contraband on-vs-off under forced despair (the FactoryBot economy never reaches despair_min).
## godot --headless --path . -s tools/contraband_scenario.gd -- --on=0|1 [--first=1 --seeds=10 --days=30 --force=4]
## Every step the first N inmates get despair >= 60. A squad of two shakes the stash down whenever one exists.
## One CBSC json line per seed.
const Bot := preload("res://tests/qa_tutorial_bot.gd")


func _init() -> void:
	var on := false
	var first := 1
	var seeds := 10
	var days := 30
	var force := 4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--on="):
			on = int(a.get_slice("=", 1)) == 1
		elif a.begins_with("--first="):
			first = int(a.get_slice("=", 1))
		elif a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
		elif a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--force="):
			force = int(a.get_slice("=", 1))
	Defs.get_default().contraband["enabled"] = on
	for sv in range(first, first + seeds):
		_run(sv, days, on, force)
	quit()


func _run(sv: int, days: int, on: bool, force: int) -> void:
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(sv, bus, null, {"tutorial": true, "research_locked": true})
	sim.start_new_game()
	var bot: RefCounted = (load("res://tools/factory_bot.gd") as GDScript).new(sim)
	var limit := days * sim.ticks_per_day
	var sid := -1
	var bumps := 0
	var shakes := 0
	while sim.tick < limit and sim.game_over_reason == "":
		bot.act()
		for qp in sim.quests.pending.duplicate():
			for qo: Dictionary in qp["options"]:
				if bool(qo["enabled"]):
					sim.answer_quest(int(qp["uid"]), str(qo["id"]))
					break
		var ids: Array = sim.debt.states.keys()
		ids.sort()
		for i in mini(force, ids.size()):
			var st: DebtState = sim.debt.states[ids[i]]
			st.despair = maxf(st.despair, 60.0)
		sim.run_ticks(Bot.STEP_TICKS)
		bot.after()
		if on:
			if sid < 0 or sim.squads.get_squad(sid) == null:
				var alive: Array = []
				for c in sim.colonists.list:
					if c.alive:
						alive.append(c.id)
				if alive.size() >= 2:
					sid = sim.form_squad([alive[alive.size() - 1], alive[alive.size() - 2]])
			if sid >= 0 and sim.contraband.stash_total() >= 3 and sim.squad_shakedown(sid):
				shakes += 1
			if sim.contraband.wave_mult() > 1.0:
				bumps += 1
	var c: Contraband = sim.contraband
	var refined := sim.ledger.get_count("recipe:" + str(c.cfg["item"]))
	print("CBSC ", JSON.stringify({"seed": sv, "on": on, "alive": sim.colonists.alive_count(), "over": sim.game_over_reason,
		"refined": refined, "skimmed": c.skimmed, "recovered": c.recovered, "leaked": c.leaked, "stash": c.stash_total(),
		"shakedowns": shakes, "blackmarkets": c.blackmarkets, "bump_steps": bumps}))
	sim.dispose()
	bus.free()
