extends SceneTree
## F3b: gear vs quota budget. Drives the factory bot (unchanged) and adds crafting bills from here.
##   godot --headless --path . -s tools/gear_budget.gd -- [--days=40 --seeds=3 --first=1 --mode=both|base|vest --from=6 --ov={json}]
## mode vest: from day `from`, one kevlar vest per living inmate (machine_parts bill + craft_gear_vest bill on the first workbench).
## Columns: refined produced, refined spent on gear (machine_parts*2 + vests*2; ore 3 per machine_part), installments paid / short
## (due-day rollovers vs inmates past the grace window with the installment unpaid), petition phases done, parts delivered, launch.
const Bot := preload("res://tests/qa_tutorial_bot.gd")
const Report := preload("res://tools/factory_bot_report.gd")


func _init() -> void:
	var days := 40
	var seeds := 3
	var first := 1
	var mode := "both"
	var from_day := 6
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
		elif a.begins_with("--first="):
			first = int(a.get_slice("=", 1))
		elif a.begins_with("--mode="):
			mode = a.get_slice("=", 1)
		elif a.begins_with("--from="):
			from_day = int(a.get_slice("=", 1))
		elif a.begins_with("--ov="):
			Report.apply_overrides(Defs.get_default(), JSON.parse_string(a.substr(5)))
	var modes: Array = ["base", "vest"] if mode == "both" else [mode]
	for sv in range(first, first + seeds):
		for m: String in modes:
			print(fmt(sv, m, play(sv, days, m == "vest", from_day)))
	quit()


static func fmt(sv: int, m: String, r: Dictionary) -> String:
	return "seed %d %-4s refined=%d gear_ref=%d (%.0f%%) gear_plate=%d vests=%d alive=%d inst_paid=%d short=%d despair>0=%d paid_debt=%d petition=%d parts=%d/%d launch=%s" % [
		sv, m, r["refined"], r["gear_ref"], 100.0 * r["gear_ref"] / maxf(1.0, r["refined"]), r["gear_plate"], r["vests"], r["alive"],
		r["inst_paid"], r["short"], r["despair"], r["paid_debt"], r["petition"], r["parts"], r["need"], r["launch"]]


static func play(seed_value: int, days: int, vests: bool, from_day: int) -> Dictionary:
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(seed_value, bus, null, {"tutorial": true, "research_locked": true})
	sim.start_new_game()
	var bot: RefCounted = (load("res://tools/factory_bot.gd") as GDScript).new(sim)
	bot.cap_percent = 35
	var due: Dictionary = {}
	var dbg := "--log" in OS.get_cmdline_user_args()
	var inst_paid := 0
	var crafted := 0
	var gb: Building = null
	var vb: Bill = null
	var limit := days * sim.ticks_per_day
	while sim.tick < limit and sim.game_over_reason == "":
		bot.act()
		if dbg and vests and sim.tick % 4000 == 100:
			print("d%d unlocked=%s gb=%s" % [sim.day(), sim.research.recipe_unlocked("craft_gear_vest"), gb != null])
		if vests and sim.day() >= from_day and sim.tick % 200 == 100 and sim.research.recipe_unlocked("craft_gear_vest"):
			if gb == null or not sim.buildings.list.has(gb):
				gb = _wb(sim)
				vb = null
			if gb != null:
				if vb == null:
					vb = sim.crafting.get_bill(gb, sim.add_bill(gb.id, "craft_gear_vest", "count", 0))
				var others := _vests(sim) - vb.done
				sim.update_bill(gb.id, vb.id, "count", maxi(vb.done, sim.colonists.alive_count() - others), false)
				if dbg and sim.tick % 1000 == 100:
					print("d%d done=%d alive=%d bench_in=%s refined=%d plate=%d" % [sim.day(), vb.done, sim.colonists.alive_count(), str(gb.input), sim.items.count_stored("refined_essence"), sim.items.count_stored("plate")])
		if vb != null:
			crafted = vb.done
		for sid: int in sim.debt.states:
			var st: DebtState = sim.debt.states[sid]
			if due.has(sid) and st.due_day > int(due[sid]):
				inst_paid += 1
			due[sid] = st.due_day
		sim.run_ticks(Bot.STEP_TICKS)
		bot.after()
	var short := 0
	var desp := 0
	var paid := 0
	for sid: int in sim.debt.states:
		var st: DebtState = sim.debt.states[sid]
		paid += st.paid
		if st.despair > 0.0:
			desp += 1
		if sim.day() >= st.due_day + int(sim.debt.cfg.get("grace_days", 0)) and st.period_paid < int(sim.debt.cfg["installment"]):
			short += 1
	var n_v := crafted
	var shuttle: Dictionary = sim.get_shuttle_state()
	var r := {
		"refined": int(sim.ledger.produced.get("refined_essence", 0)), "gear_ref": n_v * 8, "gear_plate": n_v * 5,
		"vests": n_v, "alive": sim.colonists.alive_count(), "inst_paid": inst_paid, "short": short, "despair": desp, "paid_debt": paid,
		"petition": sim.petition.done_phases.size(), "parts": int(shuttle.get("parts", 0)), "need": int(shuttle.get("need", 24)),
		"launch": "-" if bot.launch_day < 0.0 else "%.1f" % bot.launch_day,
	}
	if dbg:
		var dk := {}
		for k: String in sim.ledger.by_source:
			if k.begins_with("died") or k.begins_with("starve") or k.begins_with("raid"):
				dk[k] = sim.ledger.by_source[k]
		print("  end_day=", sim.day(), " over=", sim.game_over_reason, " gone=", sim.debt.gone, " deaths ", dk, " food=", sim.items.count_stored("raw_food") + sim.items.count_stored("meal"))
	sim.dispose()
	return r


static func _wb(sim: Simulation) -> Building:
	var last: Building = null
	for b in sim.buildings.list:
		if b.def_id == "workbench":
			last = b  # the bot's second bench (sp_wb2) when it stands, else the only one
	return last


static func _vests(sim: Simulation) -> int:
	var n := 0
	for id: int in sim.equipment.instances:
		if (sim.equipment.instances[id] as GearItem).base == "kevlar_vest":
			n += 1
	return n
