extends SceneTree
## N3: Next Sentence chain. factory_bot run 1 -> finish_sentence -> run 2 (same bot, ng opts), per seed.
## godot --headless --path . -s tools/ng_chain_report.gd -- [--days=60 --seeds=10 --first=1 --ov={"meta":{"ng.debt_carry_frac":0.5}}]
## The bot rarely launches the shuttle, so "survived <days>" counts as the run-1 result.
const FactoryBot := preload("res://tools/factory_bot.gd")
const FactoryBotReport := preload("res://tools/factory_bot_report.gd")


## One chain: returns {r1, r2, ng, seed2} (bot result dicts + the MetaState ng block after finish_sentence).
static func chain(seed_value: int, days: int) -> Dictionary:
	var m := MetaState.new()
	var o1 := m.make_opts()
	var r1: Dictionary = FactoryBot.play(seed_value, days, {"sim_opts": o1, "snapshot": true, "preset_id": m.preset})
	var snap: Dictionary = r1["snapshot"]
	m.finish_sentence(snap)
	var nx := m.make_ng_opts()
	var o2: Dictionary = nx["opts"]
	var r2: Dictionary = FactoryBot.play(int(nx["seed"]), days, {"sim_opts": o2, "snapshot": true, "preset_id": m.ng_next_preset()})
	return {"r1": r1, "r2": r2, "ng": m.ng.duplicate(true), "seed2": int(nx["seed"])}


static func line(c: Dictionary) -> String:
	var a: Dictionary = c["r1"]
	var b: Dictionary = c["r2"]
	var sa: Dictionary = a["snapshot"]
	var sb: Dictionary = b["snapshot"]
	return "seed %d | run1 %s day %d alive %d died %d debt_left %d | carry %d | run2 %s day %d alive %d died %d debt_left %d" % [
		a["seed"], "SURVIVED" if a["over"] == "" else "DEAD(" + str(a["over"]) + ")", a["end_day"], a["alive"], a["died"], sa["debt_left"],
		c["ng"]["carry_debt"], "SURVIVED" if b["over"] == "" else "DEAD(" + str(b["over"]) + ")", b["end_day"], b["alive"], b["died"], sb["debt_left"]]


func _init() -> void:
	var days := 60
	var seeds := 10
	var first := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
		elif a.begins_with("--first="):
			first = int(a.get_slice("=", 1))
		elif a.begins_with("--ov="):
			FactoryBotReport.apply_overrides(Defs.get_default(), JSON.parse_string(a.substr(5)))
	var s1 := 0
	var s2 := 0
	var d1 := 0
	var d2 := 0
	for sv in range(first, first + seeds):
		var c := chain(sv, days)
		print(line(c))
		s1 += 1 if c["r1"]["over"] == "" else 0
		s2 += 1 if c["r2"]["over"] == "" else 0
		d1 += int(c["r1"]["died"])
		d2 += int(c["r2"]["died"])
	print("TOTAL seeds=%d run1 survived=%d (deaths %d) run2 survived=%d (deaths %d) diff=%d" % [seeds, s1, d1, s2, d2, s1 - s2])
	quit()
