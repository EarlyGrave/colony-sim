extends SceneTree
## F7 W2: petition pace diagnosis (read-only; no sim change). Same bot setup as tools/la_diag.gd.
## godot --headless --path . -s tools/petition_pace.gd -- --seeds=1-10 --days=60 [--ov={"balance":{"key":val}}]
## Output per seed:
##  Pn rows: open day (P1 = day the petition becomes deliverable, i.e. audit tier 2 cleared; Pn = Pn-1 done)
##    and close day, or STILL OPEN with the BLOCKER (largest unmet item of petition.remaining(p)) and audit tier
##    reached/required (2).
##  Income rows every 5 d for plate and refined_essence: "prod" = produced in the window, then consumed per
##    ledger sink: pet (petition deliver), aud (audit), res (research), bld (construction = build + repair),
##    debt (installments), shp (shuttle), oth (everything else: the ledger sink "recipe" is shared by machine
##    inputs AND outputs, so fuel cells / machine inputs cannot be split out; craft_gear, ammo, crises have no
##    own sink either: all merged into oth). pet excludes petition reward items (P2 refined) already.
##  SUM line: first stalled phase + blocker. Footer: histogram of the stalling blocker over seeds.
const Bot := preload("res://tests/qa_tutorial_bot.gd")
const Report := preload("res://tools/factory_bot_report.gd")
const ITEMS: Array[String] = ["plate", "refined_essence"]
const SINKS := {"pet": "petition", "aud": "audit", "res": "research", "bld": "construction", "debt": "debt", "shp": "shuttle"}


func _init() -> void:
	var a := "1-10"
	var days := 60
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			a = arg.get_slice("=", 1)
		elif arg.begins_with("--days="):
			days = int(arg.get_slice("=", 1))
		elif arg.begins_with("--ov="):
			Report.apply_overrides(Defs.get_default(), JSON.parse_string(arg.substr(5)))
	print(run_many(_parse_seeds(a), days))
	quit()


static func _parse_seeds(s: String) -> Array[int]:
	var out: Array[int] = []
	if s.contains("-"):
		for i in range(int(s.get_slice("-", 0)), int(s.get_slice("-", 1)) + 1):
			out.append(i)
	else:
		for p in s.split(","):
			out.append(int(p))
	return out


static func run_many(seeds: Array[int], days: int) -> String:
	var hist: Dictionary = {}
	var out := ""
	for sd in seeds:
		var r := _run(sd, days)
		out += str(r["text"])
		var k: String = r["stall"]
		hist[k] = int(hist.get(k, 0)) + 1
	out += "HISTOGRAM of stalling blocker over %d seeds:\n" % seeds.size()
	var keys := hist.keys()
	keys.sort()
	for k in keys:
		out += "  %-34s %d\n" % [k, hist[k]]
	return out


static func run(seed_: int, days: int) -> String:
	return str(_run(seed_, days)["text"])


static func _snap(sim: Simulation) -> Dictionary:
	var d: Dictionary = {}
	for it in ITEMS:
		var row := {"prod": int(sim.ledger.produced.get(it, 0)), "cons": int(sim.ledger.consumed.get(it, 0))}
		for s: String in SINKS:
			row[s] = sim.ledger.get_count(str(SINKS[s]) + ":" + it)
		for p in sim.petition.done_phases:  # reward items share the "petition" key
			var rw: Dictionary = (sim.petition.phase_defs()[p - 1] as Dictionary).get("reward", {}).get("items", {})
			row["pet"] = int(row["pet"]) - int(rw.get(it, 0))
		d[it] = row
	return d


static func _blocker(sim: Simulation, p: int) -> String:
	var rem := sim.petition.remaining(p)
	var best := ""
	var amt := 0
	var keys := rem.keys()
	keys.sort()
	for it: String in keys:
		if int(rem[it]) > amt:
			amt = int(rem[it])
			best = it
	if best == "":
		return "none"
	var cat := best if best in ["plate", "refined_essence", "parts"] else "other"
	return "%s|%s -%d" % [cat, best, amt]


## Why next_phase() is -1 while audit tier 2 is not cleared: no terminal, or largest unmet audit T2 item.
static func _lock_blocker(sim: Simulation) -> String:
	if not sim.milestones.has_terminal():
		return "no_terminal (audit T2 short: %s)" % str(sim.milestones.remaining(2))
	var rem := sim.milestones.remaining(2)
	var best := ""
	var amt := 0
	var keys := rem.keys()
	keys.sort()
	for it: String in keys:
		if int(rem[it]) > amt:
			amt = int(rem[it])
			best = it
	return "audit_%s (T2 short %s)" % [best if best != "" else "none", str(rem)]


static func _run(sd: int, days: int) -> Dictionary:
	var bus = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(sd, bus, null, {"tutorial": true, "research_locked": true})
	sim.start_new_game()
	var bot = (load("res://tools/factory_bot.gd") as GDScript).new(sim)
	bot.cap_percent = 35
	bot.plate_target = 45
	var open_day: Dictionary = {}
	var close_day: Dictionary = {}
	var rows := ""
	var prev := _snap(sim)
	var win := sim.ticks_per_day * 5
	var lim := days * sim.ticks_per_day
	var last_win := 0
	while sim.tick < lim and sim.game_over_reason == "":
		bot.act()
		sim.run_ticks(Bot.STEP_TICKS)
		bot.after()
		var d := sim.day()
		for p in range(1, sim.petition.done_phases.size() + 1):
			if not close_day.has(p):
				close_day[p] = d
		var nxt := sim.petition.next_phase()
		if nxt > 0 and not open_day.has(nxt):
			open_day[nxt] = d
		if sim.tick / win > last_win:
			last_win = sim.tick / win
			var cur := _snap(sim)
			for it in ITEMS:
				var line := "  d%-3d %-16s prod %-4d |" % [d, it, int(cur[it]["prod"]) - int(prev[it]["prod"])]
				var named := 0
				for s: String in SINKS:
					var dv := int(cur[it][s]) - int(prev[it][s])
					named += dv
					line += " %s %d" % [s, dv]
				line += " oth %d\n" % (int(cur[it]["cons"]) - int(prev[it]["cons"]) - named)
				rows += line
			prev = cur
	var text := "SEED %d (%d d) alive=%d audit_tier=%d shuttle=%s\n" % [sd, days, sim.colonists.alive_count(), sim.milestones.tier(), str(sim.get_shuttle_state())]
	var stall := "none (all phases done)"
	var stalled := false
	for p in range(1, sim.petition.phase_count() + 1):
		if close_day.has(p):
			text += "  P%d open d%d close d%d\n" % [p, int(open_day.get(p, 0)), int(close_day[p])]
		elif open_day.has(p):
			var b := _blocker(sim, p)
			text += "  P%d open d%d STILL OPEN blocker %s, audit tier %d/2\n" % [p, int(open_day[p]), b.replace("|", " "), sim.milestones.tier()]
			if not stalled:
				stalled = true
				stall = "P%d %s" % [p, b.get_slice("|", 0)]
		else:
			var lb := _lock_blocker(sim)
			text += "  P%d not open (audit tier %d/2, terminal=%s) lock: %s\n" % [p, sim.milestones.tier(), str(sim.milestones.has_terminal()), lb]
			if not stalled:
				stalled = true
				stall = "P%d locked: %s" % [p, lb.get_slice(" ", 0)]
	text += rows
	text += "SUM seed %d: first stall %s\n" % [sd, stall]
	return {"text": text, "stall": stall}
