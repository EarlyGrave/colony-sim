extends SceneTree
## B2 table: baseline / throttle / mining bots with b2_pollution off vs on.
## godot --headless --path . -s tools/b2_table.gd [-- --days=25 --seeds=5]
const BotReport := preload("res://tools/bot_report.gd")


func _init() -> void:
	var days := 25
	var seeds := 5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var defs := Defs.get_default()
	print("profile    b2   seed end_day cause         pol%@d10 pol%@d20 final%")
	for p: String in ["baseline", "throttle", "mining"]:
		for on in [false, true]:
			defs.balance["b2_pollution"]["enabled"] = on
			defs.threat["b2_clean_outpost"]["enabled"] = on
			var sum20 := 0.0
			for sv in range(1, seeds + 1):
				var r: Dictionary = BotReport.play(sv, days, bus, p)
				var cm: Dictionary = r["contam"]
				sum20 += float(cm.get(20, r["final_contam"]))
				print("%-10s %-4s %4d %7d %-13s %7.1f %8.1f %6.1f" % [p, str(on), sv, r["end_day"], r["cause"], float(cm.get(10, 0.0)), float(cm.get(20, r["final_contam"])), r["final_contam"]])
				for c in bus.get_signal_list():
					for conn in bus.get_signal_connection_list(c["name"]):
						bus.disconnect(c["name"], conn["callable"])
			print("  -> avg pol d20 %.1f" % (sum20 / seeds))
	bus.free()
	quit()
