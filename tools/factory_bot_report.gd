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
		elif a.begins_with("--cap="):
			opts["cap"] = int(a.get_slice("=", 1))
	if "--y3=1" in OS.get_cmdline_user_args():  # region Y3
		Defs.get_default().apply_y3()
	for sv in range(first, first + seeds):
		var r: Dictionary = FactoryBot.play(sv, days, opts)
		print(format(r))
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
