extends SceneTree
## R3 QA table: baseline / automation-heavy / chip-heavy bot, seeds 1..N, D days.
## godot --headless --path . -s tools/qa_r3.gd [-- --days=25 --seeds=5]
## chip-heavy = automation-heavy until the T4 chip system exists (printed as "chips: stub").

const BotReport := preload("res://tools/bot_report.gd")
const PROFILES := ["baseline", "automation", "chip"]


func _init() -> void:
	var days := 25
	var seeds := 5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var totals := {}
	print("profile     seed  end_day  cause          kills  lost_bld  died  belt_hp_lost  repairs  peak_pol%  pol%@d10  pol%@d20  waves")
	for p: String in PROFILES:
		totals[p] = 0
		for sv in range(1, seeds + 1):
			var r: Dictionary = BotReport.play(sv, days, bus, p)
			totals[p] += int(r["end_day"])
			var cm: Dictionary = r["contam"]
			print("%-11s %4d  %7d  %-13s %6d  %8d  %4d  %12s  %7s  %9.1f  %8s  %8s  %5d" % [
				p, sv, r["end_day"], r["cause"], r["kills"], int(r.get("lost_bld", 0)), r["died"],
				"%.0f" % float(r.get("belt_hp_lost", 0.0)), str(r.get("repairs", 0)), r["peak_pol"], _f(cm.get(10)), _f(cm.get(20)), r["waves"]])
			for c in bus.get_signal_list():
				for conn in bus.get_signal_connection_list(c["name"]):
					bus.disconnect(c["name"], conn["callable"])
	var base := float(totals["baseline"])
	for p: String in PROFILES:
		print("%s: total days %d, ratio to baseline %.2f %s" % [p, totals[p], float(totals[p]) / maxf(base, 1.0),
			"OK" if float(totals[p]) <= 1.3 * base else "OVER 1.3x"])
	bus.free()
	quit()


static func _f(v: Variant) -> String:
	return "-" if v == null else "%.0f" % v
