class_name ContractSystem
extends RefCounted
## Warden quota contracts: deliver refined essence (and machine parts) by a
## deadline day. Reward on success, sanctions + warden anger on failure/decline.
## Uses its own RNG derived from the sim seed so existing random streams are untouched.

var sim: Simulation
var cfg: Dictionary
var rng := RandomNumberGenerator.new()
var list: Array[Dictionary] = []  # all contracts ever offered
var next_id := 1
var anger := 0.0
## Multiplier applied to the next raid's points (sanction > 1, reward < 1); consumed by take_raid_mult().
var next_raid_mult := 1.0
## region E2: dispatch state lives in an Object (skipped by the golden state dump, so goldens stay identical).
var e2 := RefCounted.new()


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.contracts
	rng.seed = sim.seed_value ^ 0x5C0A7
	sim.listen(sim.bus.day_started, _on_day)


func get_by_id(id: int) -> Dictionary:
	for c in list:
		if int(c["id"]) == id:
			return c
	return {}


func open_contracts(state: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in list:
		if state == "" and (c["state"] == "offered" or c["state"] == "active"):
			out.append(c)
		elif state != "" and c["state"] == state:
			out.append(c)
	return out


func take_raid_mult() -> float:
	var m := next_raid_mult
	next_raid_mult = 1.0
	if wave_mult() != 1.0:  # region E2
		m *= wave_mult()
	return m


func _on_day(day: int) -> void:
	# Deadlines and expired offers first.
	for c in list:
		if c["state"] == "active" and day >= int(c["deadline_day"]):
			_fail(c)
		elif c["state"] == "offered" and day >= int(c["expire_day"]):
			_refuse(c, "expired")
	var first := int(cfg["first_offer_day"])
	var step := int(cfg["offer_interval_days"])
	if day >= first and (day - first) % step == 0 and open_contracts().size() < int(cfg["max_open"]):
		_offer(day)


func _offer(day: int) -> void:
	var tpls: Array = cfg["templates"]
	if bool(sim.defs.balance.get("b4_enabled", false)) and cfg.has("b4_templates"):  # region B4
		tpls = tpls + (cfg["b4_templates"] as Array)
	var t: Dictionary = tpls[rng.randi_range(0, tpls.size() - 1)]
	var ess: Array = t["essence"]
	var parts: Array = t["parts"]
	var rewards: Array = t["rewards"]
	var c := {
		"id": next_id, "template": str(t["id"]), "name": str(t["name"]),
		"essence": rng.randi_range(int(ess[0]), int(ess[1])),
		"parts": rng.randi_range(int(parts[0]), int(parts[1])),
		"offered_day": day, "expire_day": day + int(cfg["offer_ttl_days"]),
		"deadline_day": 0, "deadline_days": int(t["deadline_days"]),
		"reward": (rewards[rng.randi_range(0, rewards.size() - 1)] as Dictionary).duplicate(true),
		"state": "offered",
	}
	if t.has("demand"):  # region B4
		c["demand"] = (t["demand"] as Dictionary).duplicate()
	next_id += 1
	list.append(c)
	sim.bus.contract_offered.emit(int(c["id"]))
	if c.has("demand"):  # region B4
		_say("contract_offered", "The wardens demand %d refined essence plus frontier ore (%s) within %d days. Accept the contract?" % [
			int(c["essence"]), ", ".join((c["demand"] as Dictionary).keys().map(func(k: Variant) -> String: return "%d %s" % [int(c["demand"][k]), str(k)])), int(c["deadline_days"])])
		return
	_say("contract_offered", "The wardens demand %d refined essence%s within %d days. Accept the contract?" % [
		int(c["essence"]), (" and %d parts" % int(c["parts"])) if int(c["parts"]) > 0 else "", int(c["deadline_days"])])


func accept(id: int) -> bool:
	var c := get_by_id(id)
	if c.is_empty() or c["state"] != "offered":
		return false
	c["state"] = "active"
	c["deadline_day"] = sim.day() + int(c["deadline_days"])
	return true


func decline(id: int) -> bool:
	var c := get_by_id(id)
	if c.is_empty() or c["state"] != "offered":
		return false
	_refuse(c, "declined")
	return true


func can_deliver(c: Dictionary) -> bool:
	return c.get("state", "") == "active" \
		and sim.items.count_stored("refined_essence") >= required_essence(c) \
		and sim.items.count_stored("machine_parts") >= int(c["parts"]) \
		and _has_demand(c)  # region B4


# region B4
func _has_demand(c: Dictionary) -> bool:
	var d: Dictionary = c.get("demand", {})
	for item: String in d:
		if sim.items.count_stored(item) < int(d[item]):
			return false
	return true
# endregion


func deliver(id: int) -> bool:
	var c := get_by_id(id)
	if c.is_empty() or not can_deliver(c):
		return false
	var near := sim.map_center()
	for pair: Array in [["refined_essence", required_essence(c)], ["machine_parts", int(c["parts"])]]:
		if int(pair[1]) > 0:
			sim.items.consume_stored(str(pair[0]), int(pair[1]), near)
			sim.ledger.record_consumed(str(pair[0]), int(pair[1]), "contract")
	var dem: Dictionary = c.get("demand", {})  # region B4
	for item: String in dem:
		sim.items.consume_stored(item, int(dem[item]), near)
		sim.ledger.record_consumed(item, int(dem[item]), "contract")
	c["state"] = "fulfilled"
	anger = clampf(anger + float(cfg["anger"]["on_fulfil"]), 0.0, float(cfg["anger"]["max"]))
	_reward(c)
	sim.bus.contract_fulfilled.emit(int(c["id"]))
	_say("contract_fulfilled", "Contract fulfilled. The wardens are satisfied (anger: %.1f)." % anger)
	return true


func _reward(c: Dictionary) -> void:
	var r: Dictionary = c["reward"]
	match str(r["kind"]):
		"supplies":
			var items: Dictionary = r["items"]
			for item: String in items:
				var n := int(items[item])
				sim.ledger.record_produced(item, n, "contract_reward")
				sim.items.drop(sim.map_center() + Vector2i(0, 2), item, n)
		"raid_relief":
			next_raid_mult *= float(r["mult"])
		"xp":
			var p: Variant = sim.get("progression")
			if p != null and p.has_method("grant_event_xp"):
				p.call("grant_event_xp", float(r["amount"]), "contract")


func _fail(c: Dictionary) -> void:
	c["state"] = "failed"
	_raise_anger(float(cfg["anger"]["on_fail"]))
	sim.bus.contract_failed.emit(int(c["id"]), "deadline")
	_say("contract_failed", "Contract expired! The wardens impose sanctions.")
	_sanction()


func _refuse(c: Dictionary, why: String) -> void:
	c["state"] = "declined" if why == "declined" else "expired"
	_raise_anger(float(cfg["anger"]["on_decline"]))
	sim.bus.contract_failed.emit(int(c["id"]), why)
	_say("contract_failed", "Contract refused. The wardens are displeased.")
	_sanction()


func _raise_anger(d: float) -> void:
	anger = clampf(anger + d, 0.0, float(cfg["anger"]["max"]))


func _sanction() -> void:
	var chosen: Dictionary = {}
	for s: Dictionary in cfg["anger"]["sanction_by_anger"]:
		if anger >= float(s["min"]):
			chosen = s
	if chosen.is_empty():
		return
	match str(chosen["kind"]):
		"raid_mult":
			next_raid_mult *= float(chosen["mult"])
			_say("contract_sanction", "Sanction: the next raid will be stronger.")
		"inspection":
			var alive: Array[Colonist] = []
			for col in sim.colonists.list:
				if col.alive:
					alive.append(col)
			if alive.is_empty():
				return
			var victim: Colonist = alive[rng.randi_range(0, alive.size() - 1)]
			sim.health.apply_damage(victim, float(chosen["damage"]), "", str(chosen["damage_kind"]))
			_say("contract_sanction", "Punitive inspection: %s was beaten by the wardens." % victim.display_name)


func _say(event_id: String, text: String) -> void:
	sim.bus.story_event.emit(event_id, text)


# region B2
## Essence actually due: clean-mining discount when the planet is clean (needs b2_pollution on).
func required_essence(c: Dictionary) -> int:
	var n := int(c["essence"])
	if n <= 0:
		return n
	var cb: Dictionary = cfg.get("clean_bonus", {})
	if bool(sim.defs.balance.get("b2_pollution", {}).get("enabled", false)) and not cb.is_empty() \
			and sim.contamination.is_clean(float(cb["max_pollution_frac"])):
		return maxi(1, int(ceil(n * (1.0 - float(cb["essence_discount"])))))
	return n
# endregion


# region E2
func wave_mult() -> float:
	return float(e2.get_meta("mult", 1.0))


func dispatched() -> Dictionary:
	if not e2.has_meta("done"):
		e2.set_meta("done", {})
	return e2.get_meta("done")


## Sector Dispatch (gate e2_enabled): tiers must be shipped in order; each grants one permanent modifier.
func dispatch_state() -> Dictionary:
	var out: Array = []
	var d: Dictionary = cfg.get("e2_dispatch", {})
	var nxt := next_dispatch_tier()
	for t: Dictionary in d.get("tiers", []):
		var n := int(t["tier"])
		var have := {}
		for item: String in t["bundle"]:
			have[item] = sim.items.count_stored(item)
		out.append({"tier": n, "name": t["name"], "bundle": t["bundle"], "have": have, "done": dispatched().has(n),
			"pick": dispatched().get(n, ""), "available": n == nxt and can_dispatch(n)})
	return {"enabled": bool(sim.defs.balance.get("e2_enabled", false)), "tiers": out,
		"modifiers": d.get("modifiers", []), "wave_mult": wave_mult()}


func next_dispatch_tier() -> int:
	var n := 1
	while dispatched().has(n):
		n += 1
	return n


func _e2_tier(tier: int) -> Dictionary:
	for t: Dictionary in cfg.get("e2_dispatch", {}).get("tiers", []):
		if int(t["tier"]) == tier:
			return t
	return {}


func can_dispatch(tier: int) -> bool:
	if not bool(sim.defs.balance.get("e2_enabled", false)) or tier != next_dispatch_tier():
		return false
	var t := _e2_tier(tier)
	if t.is_empty():
		return false
	for item: String in t["bundle"]:
		if sim.items.count_stored(item) < int(t["bundle"][item]):
			return false
	return true


func dispatch(tier: int, modifier_id: String) -> bool:
	if not can_dispatch(tier):
		return false
	var mod: Dictionary = {}
	for m: Dictionary in cfg["e2_dispatch"]["modifiers"]:
		if str(m["id"]) == modifier_id:
			mod = m
	if mod.is_empty() or dispatched().values().has(modifier_id):
		return false
	var t := _e2_tier(tier)
	var near := sim.map_center()
	for item: String in t["bundle"]:
		sim.items.consume_stored(item, int(t["bundle"][item]), near)
		sim.ledger.record_consumed(item, int(t["bundle"][item]), "dispatch")
	dispatched()[tier] = modifier_id
	match str(mod["kind"]):
		"wave_mult":
			e2.set_meta("mult", wave_mult() * float(mod["mult"]))
		"colonist":
			for _i in int(mod["count"]):
				var c := sim.colonists.spawn(near)
				sim.bus.colonist_joined.emit(c.id)
		"tech":
			if not sim.research.done.has(str(mod["tech"])):
				sim.research.done.append(str(mod["tech"]))
	_say("dispatch_done", "Bundle shipped to the outer cell block. %s" % str(mod["name"]))
	return true
# endregion
