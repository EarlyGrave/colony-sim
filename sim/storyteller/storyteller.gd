class_name Storyteller
extends RefCounted
## AI director. A few times a day it may fire one event from data/events.json.
## Design rule: an event breaks exactly ONE link, and a new event only comes
## when the colony is whole again (nothing broken, nobody sick, no wave).

var sim: Simulation
var cfg: Dictionary
## event id -> number of times fired
var fired: Dictionary = {}
var last_event := ""
## Open player choices: {uid, kind ("choice"|"survivor"), colonist, text,
## expires, rescued, tend_at}. Colonists here are not yet part of the colony.
var pending: Array[Dictionary] = []
var _next_uid := 1
# region event-chains
## Scheduled follow-ups: {step, due}. Processed in order, so deterministic.
var chain_queue: Array[Dictionary] = []
var lore_seen := false
var last_complication_wave := 0
## Own stream so prison events never perturb the classic roll order.
var _prng := RandomNumberGenerator.new()
# endregion


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_prng.seed = sim.seed_value ^ 0x9E3779
	cfg = sim.defs.balance["storyteller"]
	sim.listen(sim.bus.first_refine_done, func() -> void:
		_say("first_refine", "Первая партия очищена. Отходы отравляют планету — запущен прогноз конца."))
	sim.listen(sim.bus.threat_awakened, func() -> void:
		_say("awakened", "Из-под земли доносится скрежет. Твари проснулись."))
	sim.listen(sim.bus.wave_started, func(i: int, _s: float) -> void:
		_say("wave", "Волна %d! Колонисты бегут в капсулу." % i)
		_maybe_complicate(i))  # region event-chains
	sim.listen(sim.bus.enemy_killed, func(_id: int) -> void:  # region event-chains
		if not lore_seen and sim.defs.event_chains.has("first_kill_hint"):
			lore_seen = true
			_say("secret_hint", str(sim.defs.event_chains["first_kill_hint"])))
	sim.listen(sim.bus.wave_incoming, func(origin: Vector2i, _t: int) -> void:
		_say("wave_incoming", "Твари идут с %s!" % sim.threats.side_name(origin)))
	sim.listen(sim.bus.building_broken, func(id: int) -> void:
		var b := sim.buildings.get_by_id(id)
		if b:
			_say("broken", "%s сломалась — нужен ремонт." % b.def["name"]))


func tick() -> void:
	if not bool(cfg["enabled"]):
		return
	var period := maxi(1, sim.ticks_per_day / int(cfg["checks_per_day"]))
	_tick_pending()
	_tick_chains()  # region event-chains
	if sim.tick % period != 0:
		return
	var classic_fired := _roll_classic()
	if not classic_fired:
		_roll_prison()  # region event-chains


## The original one-event roll (sim.rng). True when it fired something.
func _roll_classic() -> bool:
	var whole := colony_is_whole()
	if not whole and not _has_arrival_events():
		return false
	if sim.rng.randf() >= float(cfg["chance"]):
		return false
	var id := _pick_event(whole)
	return id != "" and fire(id)


## True when no link is currently broken, so a new event is fair.
func colony_is_whole() -> bool:
	var t := sim.threats
	if t.wave_active:
		return false
	if t.awakened and t.next_wave_tick - sim.tick < int(cfg["quiet_before_wave_ticks"]):
		return false
	for b in sim.buildings.list:
		if b.broken:
			return false
	for c in sim.colonists.list:
		if c.alive and c.is_sick(sim.tick):
			return false
	return true


func _pick_event(whole: bool) -> String:
	var options: Array[String] = []
	var total := 0.0
	for id: String in sim.defs.events:
		var e: Dictionary = sim.defs.events[id]
		if e.has("requires"):
			continue  # region event-chains: prison events roll separately
		if sim.day() + 1 >= int(e["min_day"]) and (whole or not bool(e.get("harmful", true))) and _eligible(id):
			options.append(id)
			total += float(e["weight"])
	if options.is_empty():
		return ""
	var roll := sim.rng.randf() * total
	for id in options:
		roll -= float(sim.defs.events[id]["weight"])
		if roll <= 0.0:
			return id
	return options[-1]


func _eligible(id: String) -> bool:
	var e: Dictionary = sim.defs.events[id]
	if e.has("max_per_game") and int(fired.get(id, 0)) >= int(e["max_per_game"]):
		return false
	if e.has("requires"):
		return _requires_ok(e["requires"])  # region event-chains
	match id:
		"wanderer", "pod_crash":
			return _room_for(1 + pending.size()) and not _has_pending(str(e.get("kind", "")))
		"transport_drop":
			return _room_for(1 + pending.size())
		"toxic_fallout":
			return sim.contamination.fraction() >= float(e["contamination_fraction"]) \
				and not _outdoor_colonists().is_empty()
		"cargo_pod":
			return not _cargo_items().is_empty()
		"lightning":
			return not _machines().is_empty()
		"sickness":
			return _healthy_colonists().size() >= 2
		"cave_in":
			return not _designated_deposits().is_empty()
	return false


## Fires an event now (also used by tests). Returns false if it can't apply.
func fire(id: String) -> bool:
	if not _eligible(id):
		return false
	var e: Dictionary = sim.defs.events[id]
	if e.has("requires"):
		return _fire_prison(id, e)  # region event-chains
	var target := ""
	match id:
		"lightning":
			var ms := _machines()
			var b: Building = ms[sim.rng.randi_range(0, ms.size() - 1)]
			sim.buildings.wear(b, 1000.0)
			target = b.def["name"]
		"sickness":
			var cs := _healthy_colonists()
			var c: Colonist = cs[sim.rng.randi_range(0, cs.size() - 1)]
			sim.health.add_illness(c, "fever", 1.0, int(e["duration_ticks"]))  # region health
			target = c.display_name
		"cave_in":
			var ds := _designated_deposits()
			var start: Vector2i = ds[sim.rng.randi_range(0, ds.size() - 1)]
			var cells: Array[Vector2i] = [start]
			for d in MapGrid.NEIGHBORS_4:
				if cells.size() < int(e["max_cells"]) and sim.map.is_deposit(start + d):
					cells.append(start + d)
			for c in cells:
				sim.map.collapse_deposit(c)
		"wanderer":
			var w := ColonistGenerator.generate(sim, _edge_cell())
			target = w.display_name
			_post("choice", w, str(e["text"]).replace("{target}", target))
		"pod_crash":
			var pc := ColonistGenerator.generate(sim, _free_cell_near(sim.map_center(), 6))
			var dmg: Array = e["damage"]
			sim.health.apply_damage(pc, float(sim.rng.randi_range(int(dmg[0]), int(dmg[1]))), "", "bruise")
			target = pc.display_name
			_post("survivor", pc, str(e["text"]).replace("{target}", target))
		"transport_drop":
			var cnt: Array = e["count"]
			var n := sim.rng.randi_range(int(cnt[0]), int(cnt[1]))
			var names: Array[String] = []
			while n > 0 and _room_for(1):
				n -= 1
				var nc := ColonistGenerator.generate(sim, _free_cell_near(sim.map_center(), 3))
				sim.colonists.add(nc)
				names.append(nc.display_name)
			target = ", ".join(names)
		"toxic_fallout":
			var names2: Array[String] = []
			for oc in _outdoor_colonists():
				sim.health.add_illness(oc, "toxic_fallout", float(e["severity"]), int(e["duration_ticks"]))
				names2.append(oc.display_name)
			target = ", ".join(names2)
		"cargo_pod":
			var spot := _free_cell_near(sim.map_center(), 5)
			var parts: Array[String] = []
			var its := _cargo_items()
			for item in its:
				var r: Array = e["items"][item]
				var amount := sim.rng.randi_range(int(r[0]), int(r[1]))
				sim.ledger.record_produced(item, amount, "cargo_pod")
				sim.items.drop(spot, item, amount)
				parts.append("%s x%d" % [sim.defs.items[item]["name"], amount])
			target = ", ".join(parts)
	fired[id] = int(fired.get(id, 0)) + 1
	last_event = id
	_say(id, str(e["text"]).replace("{target}", target))
	return true


func _machines() -> Array[Building]:
	var out: Array[Building] = []
	for b in sim.buildings.list:
		if b.is_machine() and not b.broken:
			out.append(b)
	return out


func _healthy_colonists() -> Array[Colonist]:
	var out: Array[Colonist] = []
	for c in sim.colonists.list:
		if c.alive and not c.is_sick(sim.tick):
			out.append(c)
	return out


func _designated_deposits() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var m := sim.map
	for i in m.mine_designated.size():
		if m.mine_designated[i] != 0:
			out.append(Vector2i(i % m.width, i / m.width))
	return out


func _say(event_id: String, text: String) -> void:
	sim.bus.story_event.emit(event_id, text)


# region arrivals
## Player answer to a pending choice. wanderer: accept = joins now.
## survivor: accept = rescue (tended after a short delay, then joins);
## decline = left to their fate. Returns false for an unknown uid.
func answer(uid: int, accept: bool) -> bool:
	var p := _find_pending(uid)
	if p.is_empty():
		return false
	if p["kind"] == "chain":
		return _answer_chain(p, accept)  # region event-chains
	if p["kind"] == "survivor" and accept:
		if not bool(p["rescued"]):
			p["rescued"] = true
			p["tend_at"] = sim.tick + int(sim.defs.events["pod_crash"]["tend_delay_ticks"])
			p["expires"] = -1
			sim.bus.event_choice_resolved.emit(uid, true)
		return true
	pending.erase(p)
	var c: Colonist = p["colonist"]
	if accept and _room_for(1):
		sim.colonists.add(c)
		_say("joined", "%s присоединился к колонии." % c.display_name)
	else:
		accept = false
	sim.bus.event_choice_resolved.emit(uid, accept)
	return true


func _has_arrival_events() -> bool:
	for id: String in sim.defs.events:
		if not bool(sim.defs.events[id].get("harmful", true)) and not sim.defs.events[id].has("requires"):
			return true
	return false


func has_pending() -> bool:
	return not pending.is_empty()


func _tick_pending() -> void:
	for p in pending.duplicate():
		if p["kind"] == "chain":  # region event-chains
			if sim.tick >= int(p["expires"]):
				_answer_chain(p, false)
			continue
		var c: Colonist = p["colonist"]
		if bool(p.get("rescued", false)):
			if sim.tick >= int(p["tend_at"]) and _has_untended(c):
				sim.health.tend(c, _best_doctor())
			if not _has_untended(c):
				pending.erase(p)
				if _room_for(1):
					sim.colonists.add(c)
					_say("joined", "%s выздоравливает и присоединился к колонии." % c.display_name)
		elif int(p["expires"]) >= 0 and sim.tick >= int(p["expires"]):
			pending.erase(p)
			sim.bus.event_choice_resolved.emit(int(p["uid"]), false)
			_say("declined", "%s ушёл: никто не ответил." % c.display_name)


func _post(kind: String, c: Colonist, text: String) -> void:
	var uid := _next_uid
	_next_uid += 1
	pending.append({"uid": uid, "kind": kind, "colonist": c, "text": text, "rescued": false, "tend_at": 0,
		"expires": sim.tick + int(sim.defs.arrivals["choice_timeout_ticks"])})
	sim.bus.event_choice_posted.emit(uid, text)


func _find_pending(uid: int) -> Dictionary:
	for p in pending:
		if int(p["uid"]) == uid:
			return p
	return {}


func _has_pending(kind: String) -> bool:
	for p in pending:
		if p["kind"] == kind:
			return true
	return false


func _room_for(n: int) -> bool:
	return sim.colonists.alive_count() + n <= int(sim.defs.arrivals["max_colonists"])


func _has_untended(c: Colonist) -> bool:
	if c.health == null:
		return false
	for i in c.health.injuries:
		if not i.tended:
			return true
	return false


func _best_doctor() -> Colonist:
	var best: Colonist = null
	for c in sim.colonists.list:
		if c.alive and (best == null or c.skills.level("medicine") > best.skills.level("medicine")):
			best = c
	return best


func _outdoor_colonists() -> Array[Colonist]:
	var out: Array[Colonist] = []
	for c in sim.colonists.list:
		if c.alive and not c.hidden:
			out.append(c)
	return out


func _cargo_items() -> Array[String]:
	var out: Array[String] = []
	var e: Dictionary = sim.defs.events["cargo_pod"]
	for item: String in e["items"]:
		if sim.defs.items.has(item):
			out.append(item)
	return out


## A reachable passable map-edge cell (deterministic scan from a random start).
func _edge_cell() -> Vector2i:
	var home := sim.map_center()
	var w := sim.map.width
	var h := sim.map.height
	for attempt in 200:
		var side := sim.rng.randi_range(0, 3)
		var t := sim.rng.randi_range(0, (w if side < 2 else h) - 1)
		var c: Vector2i
		match side:
			0: c = Vector2i(t, 0)
			1: c = Vector2i(t, h - 1)
			2: c = Vector2i(0, t)
			_: c = Vector2i(w - 1, t)
		if sim.pathfinder.reachable(c, home):
			return c
	return home


func _free_cell_near(center: Vector2i, max_r: int) -> Vector2i:
	for r in range(1, max_r + 1):
		var ring: Array[Vector2i] = []
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) == r and sim.cell_free_for_items(center + Vector2i(x, y)) \
						and sim.pathfinder.reachable(center + Vector2i(x, y), center):
					ring.append(center + Vector2i(x, y))
		if not ring.is_empty():
			return ring[sim.rng.randi_range(0, ring.size() - 1)]
	return center
# endregion


# region event-chains
## Chained events: a start event (data/events_prison.json) may schedule a
## follow-up step (data/event_chains.json "steps") after a delay. Steps can
## branch on conditions, apply effects or post a player choice.

func _roll_prison() -> void:
	if not bool(sim.defs.event_chains.get("random_enabled", false)):
		return
	var whole := colony_is_whole()
	if _prng.randf() >= float(sim.defs.event_chains.get("chance", 0.3)):
		return
	var options: Array[String] = []
	var total := 0.0
	for id: String in sim.defs.events:
		var e: Dictionary = sim.defs.events[id]
		if e.has("requires") and sim.day() + 1 >= int(e["min_day"]) and (whole or not bool(e.get("harmful", true))) \
				and _eligible(id):
			options.append(id)
			total += float(e["weight"])
	if options.is_empty():
		return
	var roll := _prng.randf() * total
	for id in options:
		roll -= float(sim.defs.events[id]["weight"])
		if roll <= 0.0:
			fire(id)
			return
	fire(options[-1])


func _requires_ok(reqs: Array) -> bool:
	for r: String in reqs:
		match r:
			"debtors":
				if _debtors().is_empty():
					return false
			"essence":
				if sim.items.count_stored("refined_essence") < 1:
					return false
			"room":
				if not _room_for(1 + pending.size()):
					return false
	return true


func _fire_prison(id: String, e: Dictionary) -> bool:
	var ctx := {"target": ""}
	_apply_effects(e.get("effects", []), ctx, e)
	fired[id] = int(fired.get(id, 0)) + 1
	last_event = id
	_say(id, str(e["text"]).replace("{target}", str(ctx["target"])))
	_schedule(e.get("then", {}))
	return true


func _schedule(then: Dictionary) -> void:
	if then.is_empty():
		return
	chain_queue.append({"step": str(then["step"]),
		"due": sim.tick + maxi(1, roundi(float(then["delay_days"]) * sim.ticks_per_day))})


func _tick_chains() -> void:
	while not chain_queue.is_empty() and sim.tick >= int(chain_queue[0]["due"]):
		var q: Dictionary = chain_queue.pop_front()
		run_step(str(q["step"]))


func run_step(step_id: String) -> void:
	var steps: Dictionary = sim.defs.event_chains.get("steps", {})
	if not steps.has(step_id):
		return
	var step: Dictionary = steps[step_id]
	if step.has("branches"):
		for br: Dictionary in step["branches"]:
			if _cond_ok(br.get("if", {})):
				_apply_step(step_id, br)
				return
		return
	if step.has("choice"):
		var ch: Dictionary = step["choice"]
		var uid := _next_uid
		_next_uid += 1
		pending.append({"uid": uid, "kind": "chain", "colonist": null, "text": str(ch["text"]),
			"rescued": false, "tend_at": 0, "step": step_id,
			"yes_label": str(ch["yes_label"]), "no_label": str(ch["no_label"]),
			"expires": sim.tick + int(sim.defs.arrivals["choice_timeout_ticks"])})
		sim.bus.event_choice_posted.emit(uid, str(ch["text"]))
		return
	_apply_step(step_id, step)


func _apply_step(step_id: String, d: Dictionary) -> void:
	var ctx := {"target": ""}
	_apply_effects(d.get("effects", []), ctx, d)
	_say(step_id, str(d.get("text", "")).replace("{target}", str(ctx["target"])))
	_schedule(d.get("then", {}))


func _answer_chain(p: Dictionary, accept: bool) -> bool:
	pending.erase(p)
	var ch: Dictionary = sim.defs.event_chains["steps"][p["step"]]["choice"]
	var branch: Dictionary = ch["yes"] if accept else ch["no"]
	if accept and sim.items.count_stored("refined_essence") < int(branch.get("requires_essence", 0)):
		accept = false
		_say(str(p["step"]), str(branch.get("fail_text", "")))
	else:
		_apply_step(str(p["step"]), branch)
	sim.bus.event_choice_resolved.emit(int(p["uid"]), accept)
	return true


## Chain-step conditions. "roll" consumes sim.rng only if earlier keys passed.
func _cond_ok(cond: Dictionary) -> bool:
	for k: String in cond:
		match k:
			"essence_ok":
				if (sim.items.count_stored("refined_essence") >= quota_essence()) != bool(cond[k]):
					return false
			"has_debtors":
				if _debtors().is_empty() == bool(cond[k]):
					return false
			"roll":
				if sim.rng.randf() >= float(cond[k]):
					return false
	return true


## Essence the wardens expect to see: the largest active contract, else a default.
func quota_essence() -> int:
	var q := int(sim.defs.event_chains.get("inspection_quota_default", 0))
	if sim.contracts != null:
		for c in sim.contracts.open_contracts("active"):
			q = maxi(q, int(c["essence"]))
	return q


func _debtors() -> Array[Colonist]:
	var out: Array[Colonist] = []
	if sim.debt == null:
		return out
	for c in sim.colonists.list:
		var st := sim.debt.state_of(c)
		if c.alive and st != null and st.remaining() > 0:
			out.append(c)
	return out


func _alive_colonists() -> Array[Colonist]:
	var out: Array[Colonist] = []
	for c in sim.colonists.list:
		if c.alive:
			out.append(c)
	return out


func _apply_effects(effects: Array, ctx: Dictionary, def: Dictionary) -> void:
	for ef: Dictionary in effects:
		match str(ef["op"]):
			"despair":
				if sim.debt != null:
					for id in sim.debt.states:
						var st: DebtState = sim.debt.states[id]
						st.despair = clampf(st.despair + float(ef["amount"]), 0.0, 100.0)
			"thought":
				var cs := _alive_colonists()
				if cs.is_empty():
					continue
				if ef["who"] == "random":
					var c: Colonist = cs[sim.rng.randi_range(0, cs.size() - 1)]
					sim.mood.add_thought(c, str(ef["id"]))
					ctx["target"] = c.display_name
				else:
					for c in cs:
						sim.mood.add_thought(c, str(ef["id"]))
			"forgive":
				var ds := _debtors()
				if ds.is_empty():
					continue
				var d: Colonist = ds[sim.rng.randi_range(0, ds.size() - 1)]
				var st2 := sim.debt.state_of(d)
				st2.paid += mini(int(ef["amount"]), st2.remaining())
				ctx["target"] = d.display_name
				if st2.remaining() == 0:
					st2.pending_choice = true
					st2.despair = 0.0
					sim.bus.debt_paid.emit(d.id)
			"anger":
				if sim.contracts != null:
					sim.contracts.anger = clampf(sim.contracts.anger + float(ef["amount"]),
						0.0, float(sim.contracts.cfg["anger"]["max"]))
			"raid_mult":
				if sim.contracts != null:
					sim.contracts.next_raid_mult *= float(ef["mult"])
			"quota_up":
				if sim.contracts != null:
					for c in sim.contracts.open_contracts():
						c["essence"] = ceili(float(c["essence"]) * float(ef["mult"]))
			"supplies":
				var items: Dictionary = ef["items"]
				var spot := sim.map_center() + Vector2i(0, 2)
				for item: String in items:
					sim.ledger.record_produced(item, int(items[item]), "event_chain")
					sim.items.drop(spot, item, int(items[item]))
			"take_essence":
				var n := int(ef["n"])
				if sim.items.consume_stored("refined_essence", n, sim.map_center()):
					sim.ledger.record_consumed("refined_essence", n, "smugglers")
			"prisoners":
				var cnt: Array = def["count"]
				var k := sim.rng.randi_range(int(cnt[0]), int(cnt[1]))
				var names: Array[String] = []
				while k > 0 and _room_for(1):
					k -= 1
					var nc := ColonistGenerator.generate(sim, _free_cell_near(sim.map_center(), 3))
					sim.colonists.add(nc)
					names.append(nc.display_name)
				ctx["target"] = ", ".join(names)


## Raid complication: from wave `min_wave` on, with some chance exactly one
## of breakdown / sick colonist / cave-in accompanies the wave.
func _maybe_complicate(wave: int) -> void:
	var cc: Dictionary = sim.defs.event_chains.get("complication", {})
	if cc.is_empty() or not bool(sim.defs.event_chains.get("random_enabled", false)) or wave < int(cc["min_wave"]) or last_complication_wave >= wave:
		return
	if sim.rng.randf() >= float(cc["chance"]):
		return
	var kinds: Array[String] = []
	for k: String in cc["kinds"]:
		if (k == "breakdown" and not _machines().is_empty()) \
				or (k == "sick" and _healthy_colonists().size() >= 2) \
				or (k == "cave_in" and not _designated_deposits().is_empty()):
			kinds.append(k)
	if kinds.is_empty():
		return
	var kind := kinds[sim.rng.randi_range(0, kinds.size() - 1)]
	var target := ""
	match kind:
		"breakdown":
			var ms := _machines()
			var b: Building = ms[sim.rng.randi_range(0, ms.size() - 1)]
			sim.buildings.wear(b, float(cc["wear"]))
			target = b.def["name"]
		"sick":
			var cs := _healthy_colonists()
			var c: Colonist = cs[sim.rng.randi_range(0, cs.size() - 1)]
			sim.health.add_illness(c, "fever", 1.0, int(cc["sick_ticks"]))
			target = c.display_name
		"cave_in":
			var ds := _designated_deposits()
			var start: Vector2i = ds[sim.rng.randi_range(0, ds.size() - 1)]
			var cells: Array[Vector2i] = [start]
			for d in MapGrid.NEIGHBORS_4:
				if cells.size() < int(cc["cave_cells"]) and sim.map.is_deposit(start + d):
					cells.append(start + d)
			for cell in cells:
				sim.map.collapse_deposit(cell)
	last_complication_wave = wave
	_say("complication_" + kind, str(cc["texts"][kind]).replace("{target}", target))
# endregion
