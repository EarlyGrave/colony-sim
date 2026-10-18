class_name CrisisSystem
extends RefCounted
## Contamination thresholds become crises (data/crises.json). Each fires once
## per game, waits for the player's choice (command resolve_crisis) and applies
## the chosen option; on timeout the default option is applied. Effects are
## read by other systems only through mult()/flag()/toxic_cell().

var sim: Simulation
var cfg: Dictionary
var crises: Dictionary
## crisis id -> chosen option id ("" while still pending)
var fired: Dictionary = {}
## Open crises: {id, expires}
var pending: Array[Dictionary] = []
## Active effects: {crisis, option, mods, until (-1 = forever)}
var active: Array[Dictionary] = []
var toxic_depth := 0


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.crises["settings"]
	crises = sim.defs.crises["crises"]
	if bool(sim.defs.balance.get("b4_enabled", false)):  # region B4
		crises = crises.duplicate(true)
		var extra: Dictionary = sim.defs.crises.get("b4_options", {})
		for cid: String in extra:
			if crises.has(cid):
				(crises[cid]["options"] as Dictionary).merge(extra[cid])


func tick() -> void:
	var frac := sim.contamination.fraction()
	for id: String in crises:
		if not fired.has(id) and frac >= float(crises[id]["threshold"]):
			_start(id)
	for p in pending.duplicate():
		if sim.tick >= int(p["expires"]):
			_resolve(str(p["id"]), str(crises[p["id"]]["default_option"]), true)
	for e in active.duplicate():
		if int(e["until"]) >= 0 and sim.tick >= int(e["until"]):
			active.erase(e)
	if toxic_depth > 0 and sim.tick % int(cfg["toxic_interval_ticks"]) == 0:
		_poison_outdoors()


func _start(id: String) -> void:
	fired[id] = ""
	var c: Dictionary = crises[id]
	pending.append({"id": id, "expires": sim.tick + int(c["timeout_ticks"])})
	sim.bus.crisis_started.emit(id, str(c["text"]))
	sim.bus.story_event.emit("crisis_" + id, "%s: %s" % [c["name"], c["text"]])


func is_pending(id: String) -> bool:
	for p in pending:
		if p["id"] == id:
			return true
	return false


## Player answer. False when the crisis is not open, the option is unknown or unaffordable.
func resolve(id: String, option_id: String) -> bool:
	if not is_pending(id) or not (crises[id]["options"] as Dictionary).has(option_id):
		return false
	return _resolve(id, option_id, false)


func can_afford(id: String, option_id: String) -> bool:
	var cost: Dictionary = crises[id]["options"][option_id].get("cost", {})
	for item: String in cost:
		if sim.items.count_stored(item) < int(cost[item]):
			return false
	return true


func _resolve(id: String, option_id: String, by_timeout: bool) -> bool:
	var o: Dictionary = crises[id]["options"][option_id]
	if not by_timeout and not can_afford(id, option_id):
		return false
	var cost: Dictionary = o.get("cost", {})
	for item: String in cost:
		sim.items.consume_stored(item, int(cost[item]), sim.map_center())
		sim.ledger.record_consumed(item, int(cost[item]), "crisis")
	if o.has("contamination_delta"):
		sim.contamination.level = maxf(0.0, sim.contamination.level + float(o["contamination_delta"]))
	if o.has("delay_wave_days") and sim.threats.awakened and not sim.threats.wave_active:
		sim.threats.next_wave_tick += int(float(o["delay_wave_days"]) * sim.ticks_per_day)
	if o.has("lose_fraction"):
		_lose_stock(o["lose_fraction"])
	if o.has("toxic_edge_depth"):
		toxic_depth = maxi(toxic_depth, int(o["toxic_edge_depth"]))
	if o.has("mods"):
		var until := -1
		if o.has("duration_days"):
			until = sim.tick + int(float(o["duration_days"]) * sim.ticks_per_day)
		active.append({"crisis": id, "option": option_id, "mods": o["mods"], "until": until})
	for p in pending:
		if p["id"] == id:
			pending.erase(p)
			break
	fired[id] = option_id
	sim.bus.crisis_resolved.emit(id, option_id, by_timeout)
	sim.bus.story_event.emit("crisis_done_" + id, "%s: %s." % [crises[id]["name"], o["label"]])
	return true


func _lose_stock(fractions: Dictionary) -> void:
	for key: String in fractions:
		var ids: Array[String] = []
		if key == "waste":
			for item_id: String in sim.defs.items:
				if sim.defs.items[item_id].get("contaminates", false):
					ids.append(item_id)
		else:
			ids.append(key)
		for item_id in ids:
			var n := int(float(sim.items.count_stored(item_id)) * float(fractions[key]))
			if n > 0 and sim.items.consume_stored(item_id, n, sim.map_center()):
				sim.ledger.record_consumed(item_id, n, "crisis")


## Product of all active modifiers for a stat (1.0 when none).
func mult(stat: String) -> float:
	var m := 1.0
	for e in active:
		if (e["mods"] as Dictionary).has(stat):
			m *= float(e["mods"][stat])
	return m


func flag(stat: String) -> bool:
	for e in active:
		if (e["mods"] as Dictionary).has(stat):
			return true
	return false


func toxic_cell(c: Vector2i) -> bool:
	if toxic_depth <= 0:
		return false
	return c.x < toxic_depth or c.y < toxic_depth \
		or c.x >= sim.map.width - toxic_depth or c.y >= sim.map.height - toxic_depth


func _poison_outdoors() -> void:
	for col in sim.colonists.list:
		if not col.alive or col.hidden or not toxic_cell(col.cell):
			continue
		var has := false
		if col.health != null:
			for i in col.health.injuries:
				if i.illness_id == "toxic_fallout":
					has = true
		if not has:
			sim.health.add_illness(col, "toxic_fallout", float(cfg["toxic_severity"]), int(cfg["toxic_duration_ticks"]))
