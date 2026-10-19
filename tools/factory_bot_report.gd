extends SceneTree
## U4: real-factory bot report. godot --headless --path . -s tools/factory_bot_report.gd -- [--days=60 --seeds=5 --first=1 --nitrogen=1 --cap=50 --log]
const FactoryBot := preload("res://tools/factory_bot.gd")


func _init() -> void:
	var days := 60
	var seeds := 5
	var first := 1
	var opts := {}
	var show_log := "--log" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
		elif a.begins_with("--first="):
			first = int(a.get_slice("=", 1))
		elif a.begins_with("--nitrogen="):
			opts["assume_nitrogen"] = int(a.get_slice("=", 1)) == 1
		elif a.begins_with("--plate="):
			opts["plate"] = int(a.get_slice("=", 1))
		elif a.begins_with("--cap="):
			opts["cap"] = int(a.get_slice("=", 1))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ov="):  # YX: --ov={"balance":{"mining.yield":10},"recipes":{"refine_essence.outputs.refined_essence":5}}
			apply_overrides(Defs.get_default(), JSON.parse_string(a.substr(5)))
	for sv in range(first, first + seeds):
		var r: Dictionary = FactoryBot.play(sv, days, opts)
		print(format(r))
		if "--json" in OS.get_cmdline_user_args():  # region D4
			print(json_line(r))
		if show_log:
			for l: String in r["log"]:
				print("   ", l)
	quit()


static func format(r: Dictionary) -> String:
	var pd: Array = r["phase_day"]
	var ps: Array[String] = []
	for d: float in pd:
		ps.append("-" if d < 0.0 else "%.0f" % d)
	return "seed %d audit2=%s P1..P4=%s parts=%d/%d launch=%s won=%s min_hp=%d alive=%d died=%d pol=%.0f%% food=%d over=%s debt=%.0f%% | blocker: %s | nitrogen_nodes=%d steps=%d built=%s pf=%.2f ledger(prod/cons)=%s" % [
		r["seed"], "-" if r["audit_day"] < 0.0 else "%.0f" % r["audit_day"], ",".join(ps), r["parts"], r["need"],
		"-" if r["launch_day"] < 0.0 else "%.1f" % r["launch_day"], "-" if r["won_day"] < 0.0 else "%.1f" % r["won_day"],
		r["min_hp"], r["alive"], r["died"], r["pollution"], r["food"], r["over"], r["debt_pct"], r["blocker"],
		r["nitrogen_nodes"], r["steps"], str(r["built"]), r["power_factor"], str(r["ledger"])]


## YX: sweep helper. ov = {defs_property: {"a.b.c": value}} applied to the default Defs (tools only, never the game).
static func apply_overrides(d: Defs, ov: Dictionary) -> void:
	for prop: String in ov:
		var root: Variant = d.get(prop)
		if not (root is Dictionary):
			continue
		for path: String in ov[prop]:
			var parts := path.split(".")
			var cur: Dictionary = root
			for i in range(parts.size() - 1):
				if not cur.has(parts[i]) or not (cur[parts[i]] is Dictionary):
					cur = {}
					break
				cur = cur[parts[i]]
			if parts.size() > 0 and (cur.has(parts[-1]) or not cur.is_empty()):
				cur[parts[-1]] = ov[prop][path]


# region D4
## One machine-readable line per seed for tools/factory_eval.sh.
static func json_line(r: Dictionary) -> String:
	var led: Dictionary = r["ledger"]
	var pd: Array = r["phase_day"]
	var built: Dictionary = r["built"]
	var p: Array = []
	for i in range(4):
		p.append(i < pd.size() and float(pd[i]) >= 0.0)
	return "EVALJSON " + JSON.stringify({
		"seed": r["seed"], "over": r["over"], "alive": r["alive"], "audit": float(r["audit_day"]) >= 0.0,
		"p": p, "parts": r["parts"], "need": r["need"], "launch": float(r["launch_day"]) >= 0.0, "pol": r["pollution"],
		"debt": r["debt_pct"], "refined": int(str(led["refined_essence"]).get_slice("/", 0)),
		"plates": int(built.get("stock_plate", 0)), "waste": r["waste_prod"], "audit_day": r["audit_day"], "quests": r.get("quests", []), "blocker": r["blocker"]})
# endregion
