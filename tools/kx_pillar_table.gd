extends SceneTree
## KX pillar table: waves by day N for baseline / throttle / mining bots on one preset.
## godot --headless --path . -s tools/kx_pillar_table.gd -- --days=21 --seeds=5 [--preset=standard_term] [--mult=1.5] [--audit=4] [--pts=0.7] [--profiles=baseline,throttle]
const BotReport := preload("res://tools/bot_report.gd")


func _init() -> void:
	var days := 21
	var seeds := 5
	var preset := "standard_term"
	var profiles := ["baseline", "throttle", "mining"]
	var d := Defs.get_default()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
		elif a.begins_with("--preset="):
			preset = a.get_slice("=", 1)
		elif a.begins_with("--profiles="):
			profiles = Array(a.get_slice("=", 1).split(","))
		elif a.begins_with("--mult="):
			for id: String in d.presets["presets"]:
				d.presets["presets"][id]["wave_interval_mult"] = float(a.get_slice("=", 1))
		elif a.begins_with("--audit="):
			d.presets["presets"][preset]["audit_interval_days"] = float(a.get_slice("=", 1))
		elif a.begins_with("--clean="):
			d.balance["pacing"]["pollution_interval"]["clean_mult"] = float(a.get_slice("=", 1))
		elif a.begins_with("--dirty="):
			d.balance["pacing"]["pollution_interval"]["dirty_mult"] = float(a.get_slice("=", 1))
		elif a.begins_with("--lo="):
			d.balance["pacing"]["pollution_interval"]["lo"] = float(a.get_slice("=", 1))
		elif a.begins_with("--hi="):
			d.balance["pacing"]["pollution_interval"]["hi"] = float(a.get_slice("=", 1))
		elif a.begins_with("--pts="):
			d.balance["pacing"]["floor_pts_per_day"] = float(a.get_slice("=", 1))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ovf="):  # YX: JSON file {defs_property: {"a.b.c": value}} (see factory_bot_report.apply_overrides)
			(load("res://tools/factory_bot_report.gd") as GDScript).apply_overrides(d, JSON.parse_string(FileAccess.get_file_as_string(a.substr(6))))
	BotReport.preset_id = preset
	var bus: Node = load("res://autoload/event_bus.gd").new()
	for p: String in profiles:
		var waves := 0
		var deaths := 0
		var per: Array = []
		for s in range(1, seeds + 1):
			var r: Dictionary = BotReport.play(s, days, bus, p)
			waves += int(r["waves"])
			deaths += int(r["died"])
			per.append(int(r["waves"]))
			for c in bus.get_signal_list():
				for conn in bus.get_signal_connection_list(c["name"]):
					bus.disconnect(c["name"], conn["callable"])
		print("%s d%d %-9s mean_waves=%.1f deaths=%d per_seed=%s" % [preset, days, p, float(waves) / seeds, deaths, str(per)])
	bus.free()
	quit()
