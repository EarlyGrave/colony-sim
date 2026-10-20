class_name ForecastPanel
extends GamePanel
## C5: pre-wave forecast. Pure read of the sim (no new state, no rng): what the next wave can
## be made of, from which side, when, and how loud the colony is. The exact composition is only
## rolled when the wave starts, so this shows the possible raid types and an expected head-count.

var _label: Label


## Forecast numbers for the next (or running) wave.
static func forecast(sim: Simulation) -> Dictionary:
	var t: ThreatSystem = sim.threats
	var out := {"awake": t.awakened, "active": t.wave_active, "index": t.wave_index + 1, "eta_ticks": -1,
		"eta_hours": 0.0, "side": "", "points": 0.0, "types": [], "count_lo": 0, "count_hi": 0,
		"taint": sim.contamination.fraction(), "left": t.enemies.size()}
	if t.wave_active:
		out["index"] = t.wave_index
		out["side"] = t.side_name(t.next_spawn_origin) if t.next_spawn_origin.x >= 0 else ""
		return out
	if not t.awakened or t.next_wave_tick < 0:
		return out
	out["eta_ticks"] = maxi(0, t.next_wave_tick - sim.tick)
	out["eta_hours"] = float(out["eta_ticks"]) * 24.0 / float(sim.ticks_per_day)
	if t.next_spawn_origin.x >= 0:
		out["side"] = t.side_name(t.next_spawn_origin)
	var pts := t.raid_points(t.wave_index + 1)
	if t.wave_index == 0:
		pts = minf(pts, float(t.cfg["first_wave_max_points"]))
	out["points"] = pts
	var ids: Array[String] = []
	var total := 0.0
	for id: String in sim.defs.raids:
		var r: Dictionary = sim.defs.raids[id]
		if float(r["min_points"]) <= pts and not r.get("scripted", false) and r.get("faction", "creature") == "creature":  # F2e: no drone rows
			ids.append(id)
			total += float(r["weight"])
	var lo := 1 << 30
	var hi := 0
	for id in ids:
		var r: Dictionary = sim.defs.raids[id]
		var uw := 0.0
		var uc := 0.0
		var names: Array[String] = []
		for u: Dictionary in r.get("units", []):
			var e: Dictionary = sim.defs.enemies[u["enemy"]]
			uw += float(u["weight"])
			uc += float(u["weight"]) * float(e["threat_cost"])
			names.append(str(e["name"]))
		var n := roundi(pts / maxf(0.1, uc / maxf(0.1, uw)))
		lo = mini(lo, n)
		hi = maxi(hi, n)
		(out["types"] as Array).append({"id": id, "name": str(r["name"]), "share": float(r["weight"]) / maxf(0.1, total), "units": ", ".join(names), "count": n})
	out["count_lo"] = 0 if ids.is_empty() else lo
	out["count_hi"] = hi
	return out


static func describe(f: Dictionary) -> String:
	if not f["awake"]:
		return "The creatures sleep.\nThey stir when the first essence is refined."
	if f["active"]:
		return "Wave %d is here: %d creatures left%s.\nHold the line, or sound the alarm." % [f["index"], f["left"], (" from the " + str(f["side"])) if f["side"] != "" else ""]
	var lines: Array[String] = []
	lines.append("Wave %d in %.1f h%s." % [f["index"], f["eta_hours"], (", from the " + str(f["side"])) if f["side"] != "" else ""])
	var n_lo := int(f["count_lo"])
	var n_hi := int(f["count_hi"])
	lines.append("Expect about %s creatures (strength %.1f)." % [str(n_lo) if n_lo == n_hi else "%d-%d" % [n_lo, n_hi], f["points"]])
	for t: Dictionary in f["types"]:
		lines.append("%d%%  %s: %s" % [roundi(float(t["share"]) * 100.0), t["name"], t["units"]])
	lines.append("Taint %.0f%%: more refining, bigger waves." % (float(f["taint"]) * 100.0))
	return "\n".join(lines)


func build() -> void:
	_label = add_line("")
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", 16)


func refresh() -> void:
	if sim != null and _label != null:
		_label.text = describe(forecast(sim))
