extends SceneTree
## B1: preset ramp table. godot --headless --path . -s tools/b1_preset_table.gd [-- --days=25 --seeds=5]
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
	for id in (OS.get_environment("PRESETS").split(",") if OS.get_environment("PRESETS") != "" else ["short_stay", "standard_term", "hard_time"]):
		BotReport.preset_id = id
		var deaths := 0
		var waves := 0
		var pol := 0.0
		var ends: Array = []
		for s in range(1, seeds + 1):
			var r := BotReport.play(s, days, bus)
			deaths += int(r["died"])
			waves += int(r["waves"])
			pol += float(r["contam"].get(20, r["final_contam"]))
			ends.append("%d%s" % [r["end_day"], "" if r["cause"] == "alive" else "!"])
			for c in bus.get_signal_list():
				for conn in bus.get_signal_connection_list(c["name"]):
					bus.disconnect(c["name"], conn["callable"])
		print("%-14s mean_waves=%.1f deaths=%d waves=%d pol%%d20=%.1f ends=%s" % [id, float(waves) / seeds, deaths, waves, pol / seeds, str(ends)])
	bus.free()
	quit()
