extends SceneTree
## W3: contraband off-vs-on report (read-only use of factory_bot / bot_report).
## godot --headless --path . -s tools/contraband_report.gd -- --on=0|1 [--mode=bot|pillar] [--first=1 --seeds=1 --days=60]
## bot: one CBJSON line per seed (alive, skim totals, shakedowns possible, wave bump). pillar: waves for baseline/throttle.
const FactoryBot := preload("res://tools/factory_bot.gd")
const Bot := preload("res://tests/qa_tutorial_bot.gd")
const BotReport := preload("res://tools/bot_report.gd")


func _init() -> void:
	var on := false
	var mode := "bot"
	var first := 1
	var seeds := 1
	var days := 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--on="):
			on = int(a.get_slice("=", 1)) == 1
		elif a.begins_with("--mode="):
			mode = a.get_slice("=", 1)
		elif a.begins_with("--first="):
			first = int(a.get_slice("=", 1))
		elif a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
		elif a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
	Defs.get_default().contraband["enabled"] = on
	for sv in range(first, first + seeds):
		if mode == "pillar":
			_pillar(sv, days, on)
		else:
			_bot(sv, days, on)
	quit()


func _pillar(sv: int, days: int, on: bool) -> void:
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var out := {"seed": sv, "on": on}
	for p: String in ["baseline", "throttle"]:
		BotReport.preset_id = "standard_term"
		var r: Dictionary = BotReport.play(sv, days, bus, p)
		out[p] = int(r["waves"])
	print("CBPILLAR ", JSON.stringify(out))
	bus.free()


func _bot(sv: int, days: int, on: bool) -> void:
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(sv, bus, null, {"tutorial": true, "research_locked": true})
	sim.start_new_game()
	var bot: RefCounted = (load("res://tools/factory_bot.gd") as GDScript).new(sim)
	var limit := days * sim.ticks_per_day
	var bumps := 0
	var shake_ok := 0
	while sim.tick < limit and sim.game_over_reason == "":
		bot.act()
		for qp in sim.quests.pending.duplicate():
			for qo: Dictionary in qp["options"]:
				if bool(qo["enabled"]):
					sim.answer_quest(int(qp["uid"]), str(qo["id"]))
					break
		sim.run_ticks(Bot.STEP_TICKS)
		bot.after()
		if sim.contraband.wave_mult() > 1.0:
			bumps += 1
		if sim.contraband.stash_total() > 0:
			shake_ok += 1
	var c: Contraband = sim.contraband
	print("CBJSON ", JSON.stringify({"seed": sv, "on": on, "alive": sim.colonists.alive_count(), "over": sim.game_over_reason,
		"skimmed": c.skimmed, "recovered": c.recovered, "leaked": c.leaked, "stash": c.stash_total(), "blackmarkets": c.blackmarkets,
		"bump_steps": bumps, "stash_steps": shake_ok, "debt": sim.milestones.debt_paid_pct()}))
	sim.dispose()
	bus.free()
