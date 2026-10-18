extends SceneTree
## C5 QA table: 25 game days x seeds 1..5, "with squad" vs "no squad".
##   godot --headless --path . -s tools/combat_report.gd [-- --days=25]

const Bot := preload("res://tests/qa_combat_bot.gd")


func _init() -> void:
	var days := 25
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.substr(7))
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var sums := {false: {"repelled": 0, "dead": 0, "down_sec": 0.0, "essence_spent": 0, "taint_pct": 0.0, "waves": 0}, true: {"repelled": 0, "dead": 0, "down_sec": 0.0, "essence_spent": 0, "taint_pct": 0.0, "waves": 0}}
	print("%d days | mode      | seed | waves | repelled | dead | down s | taint%% | ess spent | over" % days)
	for seed_value in [1, 2, 3, 4, 5]:
		for with_squad in [false, true]:
			var r: Dictionary = Bot.run(seed_value, with_squad, days, 2, bus)
			print("        | %-9s | %4d | %5d | %8d | %4d | %6.1f | %6.1f | %9d | %s" % [
				"squad" if with_squad else "no squad", seed_value, r["waves"], r["repelled"], r["dead"], r["down_sec"], r["taint_pct"], r["essence_spent"], r["over"]])
			for k: String in sums[with_squad]:
				sums[with_squad][k] += r[k]
			for c in bus.get_signal_list():
				for conn in bus.get_signal_connection_list(c["name"]):
					bus.disconnect(c["name"], conn["callable"])
	for with_squad in [false, true]:
		var s: Dictionary = sums[with_squad]
		print("TOTAL %-9s waves=%d repelled=%d dead=%d down_s=%.1f taint_sum=%.1f ess_spent=%d" % ["squad" if with_squad else "no squad", s["waves"], s["repelled"], s["dead"], s["down_sec"], s["taint_pct"], s["essence_spent"]])
	var d0: int = sums[false]["dead"]
	var d1: int = sums[true]["dead"]
	print("colonists_dead: %d -> %d (%s)" % [d0, d1, ("%.0f%% fewer" % (100.0 * float(d0 - d1) / float(d0))) if d0 > 0 else "baseline has no deaths"])
	# Per wave, so a longer-surviving game does not skew the comparison.
	var r0: int = sums[false]["repelled"]
	var r1: int = sums[true]["repelled"]
	var pw0 := float(d0) / maxf(1.0, float(r0))
	var pw1 := float(d1) / maxf(1.0, float(r1))
	print("deaths per repelled wave: %.2f -> %.2f (%.0f%% fewer, target >= 30%%)" % [pw0, pw1, 100.0 * (pw0 - pw1) / maxf(0.001, pw0)])
	var w0: int = sums[false]["waves"]
	var w1: int = sums[true]["waves"]
	pw0 = float(d0) / maxf(1.0, float(w0))
	pw1 = float(d1) / maxf(1.0, float(w1))
	print("deaths per wave faced:    %.2f -> %.2f (%.0f%% fewer)" % [pw0, pw1, 100.0 * (pw0 - pw1) / maxf(0.001, pw0)])
	bus.free()
	quit()
