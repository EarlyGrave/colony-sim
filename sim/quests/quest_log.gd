class_name QuestLog
extends RefCounted
## Data-driven quest engine (Q0). Gated by balance "q_enabled" (default false).
## Quests live in data/quests*.json; beats post letters and N-way choices; effects are a small verb set.
## Deterministic: all randomness via sim.rng, timers in ticks. State shows up in state_hash only after a quest started.

const MOD_DEFAULTS := {"audit_parts_mult": 1.0, "wave_mult": 1.0, "refine_mult": 1.0, "fine_pct": 0.0, "petition_fee_mult": 1.0}
const MAX_DEBT_CUT_PCT := 2.0

var sim: Simulation
## quest id -> {state, beat, refs{name:colonist id}}
var quests: Dictionary = {}
var flags: Dictionary = {}
## mod name -> {value, until}
var _mods: Dictionary = {}
## [{quest, beat, due}] sorted by due, then insertion order
var _schedule: Array[Dictionary] = []
## [{uid, quest, beat, text, options:[{id,label,enabled}]}]
var pending: Array[Dictionary] = []
## [[tick, quest, beat]] history (determinism checks, HUD)
var log: Array = []
var _next_uid := 1
## custom trigger conditions: name -> Callable(arg) -> bool (other quest modules register theirs)
var _conds: Dictionary = {}
var _poll_ids: Array = []
## code-driven quests: quest id -> object with poll(), resolve(option_id), state_parts()
var _modules: Dictionary = {}


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	if not is_enabled():
		return
	sim.listen(sim.bus.day_started, _on_day)
	sim.listen(sim.bus.tick_advanced, _on_tick)


func is_enabled() -> bool:
	return bool(sim.defs.balance.get("q_enabled", false))


func is_started() -> bool:
	return has_state()


func has_state() -> bool:
	return not quests.is_empty() or not flags.is_empty()


func state(id: String) -> String:
	return str(quests[id]["state"]) if quests.has(id) else "idle"


func flag(id: String) -> bool:
	return bool(flags.get(id, false))


func set_flag(id: String) -> void:
	flags[id] = true


func ref(quest_id: String, name: String) -> int:
	return int(quests.get(quest_id, {}).get("refs", {}).get(name, -1))


func set_ref(quest_id: String, name: String, colonist_id: int) -> void:
	if quests.has(quest_id):
		quests[quest_id]["refs"][name] = colonist_id


## Registers a code quest. It is polled once per day; answers to its offers go to module.resolve(option_id).
func register_module(quest_id: String, module: Object) -> void:
	_modules[quest_id] = module


## Absolute-expiry variant (expiry_tick in sim ticks).
func set_mod_until(name: String, value: float, expiry_tick: int) -> void:
	_mods[name] = {"value": value, "until": expiry_tick}


func set_mod(name: String, value: float, days: float) -> void:
	add_mod(name, value, days)


func register_cond(name: String, fn: Callable) -> void:
	_conds[name] = fn


## Mod value; default (1.0 / 0.0) once expired.
func mod(name: String) -> float:
	var d: float = MOD_DEFAULTS.get(name, 1.0)
	if not _mods.has(name):
		return d
	var m: Dictionary = _mods[name]
	return float(m["value"]) if sim.tick < int(m["until"]) else d


func add_mod(name: String, value: float, days: float) -> void:
	## days <= 0 means permanent
	var until := 1 << 60 if days <= 0.0 else sim.tick + maxi(1, roundi(days * sim.ticks_per_day))
	_mods[name] = {"value": value, "until": until}


func start(id: String) -> bool:
	if not is_enabled() or not sim.defs.quests.has(id) or state(id) != "idle":
		return false
	quests[id] = {"state": "active", "beat": "", "refs": {}}
	sim.bus.quest_started.emit(id)
	_enter(id, str(sim.defs.quests[id].get("start", "start")))
	return true


func schedule(quest_id: String, beat_id: String, delay_days: float) -> void:
	var due := sim.tick + maxi(0, roundi(delay_days * sim.ticks_per_day))
	var i := _schedule.size()
	while i > 0 and int(_schedule[i - 1]["due"]) > due:
		i -= 1
	_schedule.insert(i, {"quest": quest_id, "beat": beat_id, "due": due})


## Posts an N-way choice. options: [{id, label, enabled?}]. Returns the uid.
func offer(quest_id: String, beat_id: String, text: String, options: Array) -> int:
	var uid := _next_uid
	_next_uid += 1
	var opts: Array = []
	for o: Dictionary in options:
		opts.append({"id": str(o["id"]), "label": str(o.get("label", o["id"])), "enabled": bool(o.get("enabled", true))})
	pending.append({"uid": uid, "quest": quest_id, "beat": beat_id, "text": text, "options": opts})
	sim.bus.quest_choice_posted.emit(uid, quest_id, opts)
	return uid


func answer(uid: int, option_id: String) -> bool:
	for p in pending:
		if int(p["uid"]) != uid:
			continue
		var chosen: Dictionary = {}
		for o: Dictionary in p["options"]:
			if o["id"] == option_id:
				chosen = o
		if chosen.is_empty() or not bool(chosen["enabled"]):
			return false
		pending.erase(p)
		if _modules.has(p["quest"]):
			sim.bus.quest_resolved.emit(str(p["quest"]), option_id)
			_modules[p["quest"]].resolve(option_id)
			return true
		_resolve(str(p["quest"]), str(p["beat"]), option_id)
		return true
	return false


func pending_for(quest_id: String) -> Dictionary:
	for p in pending:
		if p["quest"] == quest_id:
			return p
	return {}


func active_ids() -> Array:
	var out: Array = []
	for id: String in _sorted(quests.keys()):
		if quests[id]["state"] == "active":
			out.append(id)
	return out


func _sorted(a: Array) -> Array:
	a.sort()
	return a


# --- engine ---

func _on_day(_d: int) -> void:
	for qid: String in _sorted(_modules.keys()):
		_modules[qid].poll()
	if _poll_ids.is_empty():
		_poll_ids = _sorted(sim.defs.quests.keys())
	for id: String in _poll_ids:
		if state(id) == "idle" and sim.defs.quests[id].has("trigger") and _trigger_ok(sim.defs.quests[id]["trigger"]):
			start(id)


func _on_tick(_t: int) -> void:
	while not _schedule.is_empty() and int(_schedule[0]["due"]) <= sim.tick:
		var s: Dictionary = _schedule.pop_front()
		if state(str(s["quest"])) == "active":
			_enter(str(s["quest"]), str(s["beat"]))


func _trigger_ok(t: Dictionary) -> bool:
	for k: String in t:
		var v: Variant = t[k]
		match k:
			"min_day":
				if sim.day() < int(v):
					return false
			"flag":
				if not flag(str(v)):
					return false
			"not_flag":
				if flag(str(v)):
					return false
			"quest_done":
				if state(str(v)) != "done":
					return false
			"tier_done":
				if not sim.milestones.is_tier_done(int(v)):
					return false
			"pollution_over":
				if sim.contamination.level <= float(v):
					return false
			"reviews_done":
				if sim.milestones.reviews_done.size() < int(v):
					return false
			_:
				if not _conds.has(k) or not bool(_conds[k].call(v)):
					return false
	return true


func _enter(qid: String, beat_id: String) -> void:
	var beats: Dictionary = sim.defs.quests[qid].get("beats", {})
	if not beats.has(beat_id):
		_finish(qid)
		return
	var b: Dictionary = beats[beat_id]
	quests[qid]["beat"] = beat_id
	log.append([sim.tick, qid, beat_id])
	var text := str(b.get("text", ""))
	sim.bus.quest_beat.emit(qid, beat_id, text)
	if text != "":
		sim.bus.story_event.emit("quest_" + qid, text)
	if b.has("effects"):
		_apply_effects(qid, b["effects"])
	if b.has("options"):
		var opts: Array = []
		for oid: String in _sorted(b["options"].keys()):
			var o: Dictionary = b["options"][oid]
			opts.append({"id": oid, "label": str(o.get("label", o.get("text", oid))), "enabled": _requires_ok(o.get("requires", {}))})
		offer(qid, beat_id, text, opts)
	elif b.has("then"):
		schedule(qid, str(b["then"]), float(b.get("delay_days", 1.0)))
	else:
		_finish(qid)


func _resolve(qid: String, beat_id: String, opt_id: String) -> void:
	var o: Dictionary = sim.defs.quests[qid]["beats"][beat_id]["options"][opt_id]
	flags["%s.%s" % [qid, opt_id]] = true
	_apply_effects(qid, o.get("effects", []))
	var txt := str(o.get("text", ""))
	if txt != "":
		sim.bus.story_event.emit("quest_" + qid, txt)
	sim.bus.quest_resolved.emit(qid, opt_id)
	if o.has("then"):
		schedule(qid, str(o["then"]), float(o.get("delay_days", 1.0)))
	else:
		_finish(qid)


func _finish(qid: String) -> void:
	if quests.has(qid):
		quests[qid]["state"] = "done"


func _requires_ok(r: Dictionary) -> bool:
	if r.has("item") and sim.items.count_stored(str(r["item"])) < int(r.get("n", 1)):
		return false
	var its: Variant = r.get("items", null)  # {item: n} or [{item, n}]
	if its is Dictionary:
		for k: String in its:
			if sim.items.count_stored(k) < int(its[k]):
				return false
	elif its is Array:
		for e: Dictionary in its:
			if sim.items.count_stored(str(e["item"])) < int(e.get("n", 1)):
				return false
	return true


func _apply_effects(qid: String, effects: Array) -> void:
	for e: Dictionary in effects:
		if e.has("chance") and sim.rng.randf() >= float(e["chance"]):
			continue
		match str(e.get("verb", "")):
			"flag":
				set_flag(str(e["id"]))
			"mod":
				add_mod(str(e["name"]), float(e["value"]), float(e.get("days", 1.0)))
			"items":
				_fx_items(str(e["item"]), int(e["n"]))
			"mood":
				_fx_mood(qid, e)
			"debt_pct":
				_fx_debt(qid, e)
			"spawn_colonist":
				var nc := ColonistGenerator.generate(sim, sim.storyteller._free_cell_near(sim.map_center(), 3))
				sim.colonists.add(nc)
				if e.has("as"):
					quests[qid]["refs"][str(e["as"])] = nc.id
			"remove_colonist":
				var c := sim.colonists.get_by_id(ref(qid, str(e.get("who", ""))))
				if c != null and c.alive:
					sim.colonists.kill(c)
			"pollution":  # value = fraction of the planet's max (0.03 = +3%)
				var mx := float(sim.defs.balance["contamination"]["max"])
				sim.contamination.level = clampf(sim.contamination.level + float(e["value"]) * mx, 0.0, mx * 0.999)
			"letter":
				sim.bus.letter_received.emit(str(e.get("title", "Dispatch")), str(e.get("text", "")))


func _fx_items(item: String, n: int) -> void:
	# n < 0 spends stored items
	var near := sim.map_center()
	if n > 0:
		sim.items.drop(near, item, n)
	elif n < 0:
		sim.items.consume_stored(item, -n, near)


func _fx_mood(qid: String, e: Dictionary) -> void:
	var th := str(e.get("thought", ""))
	if e.has("who"):
		sim.mood.add_thought(sim.colonists.get_by_id(ref(qid, str(e["who"]))), th)
		return
	for c in sim.colonists.list:
		if c.alive:
			sim.mood.add_thought(c, th)


## pct < 0 cuts debt (total cut over all debtors clamped to 2% of the colony's remaining debt); pct > 0 adds interest.
func _fx_debt(qid: String, e: Dictionary) -> void:
	var pct := float(e["pct"])
	var who: Array = []
	var total_rem := 0
	for c in sim.colonists.list:
		var st := sim.debt.state_of(c)
		if st == null:
			continue
		total_rem += st.remaining()
		if not e.has("who") or c.id == ref(qid, str(e["who"])):
			who.append(st)
	var cut_cap := int(floor(total_rem * MAX_DEBT_CUT_PCT / 100.0))
	for st: DebtState in who:
		var d := int(round(st.remaining() * absf(pct) / 100.0))
		if pct < 0.0:
			d = mini(d, cut_cap)
			cut_cap -= d
			st.total -= d
		else:
			st.total += d


func state_parts() -> Array:
	var out: Array = []
	var mp: Array = []
	for qid: String in _sorted(_modules.keys()):
		var part: Array = _modules[qid].state_parts()
		if not part.is_empty():
			mp.append([qid, part])
	if not has_state() and mp.is_empty():
		return out
	var qs: Array = []
	for id: String in _sorted(quests.keys()):
		var q: Dictionary = quests[id]
		var refs: Array = []
		for r: String in _sorted(q["refs"].keys()):
			refs.append([r, q["refs"][r]])
		qs.append([id, q["state"], q["beat"], refs])
	var ms: Array = []
	for m: String in _sorted(_mods.keys()):
		ms.append([m, _mods[m]["value"], _mods[m]["until"]])
	var sc: Array = []
	for s in _schedule:
		sc.append([s["quest"], s["beat"], s["due"]])
	var pd: Array = []
	for p in pending:
		pd.append([p["uid"], p["quest"], p["beat"]])
	return ["quests", qs, _sorted(flags.keys()), ms, sc, pd, mp]
