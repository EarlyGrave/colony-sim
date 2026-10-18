class_name QaCombatBot
extends RefCounted
## C5 QA: a deterministic player that fights waves with ONE squad of three roles (public commands
## only), versus the same colony with no squad (current behaviour: the alarm sends everyone hiding).
##
## Squad commands come from C1/C2 when present (`form_squad`, `squad_hold`, `squad_focus`,
## `use_ability`, `disband_squad`, guarded with has_method). Until those are merged the bot falls
## back to the equivalent plain commands (`set_drafted` + `order_move` / `order_attack` on the three
## picked inmates), which is exactly what the plan says squad_hold / squad_focus do to members.
## `run()` reports which path it used in "squad_api".

const Scen := preload("res://tests/scenario.gd")
const ROLES := ["bulwark", "lancer", "medic"]
const ACT_PERIOD := 20


## One game: `days` days on `seed_value`. Returns the table row.
static func run(seed_value: int, with_squad: bool, days := 25, turrets := 2, bus: Node = null) -> Dictionary:
	var own_bus := bus == null
	if own_bus:
		bus = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(seed_value, bus)
	sim.start_new_game()
	Scen.standard_colony(sim, turrets)
	var row := {"seed": seed_value, "squad": with_squad, "repelled": 0, "dead": 0, "down_sec": 0.0, "squad_api": sim.has_method("form_squad")}
	sim.bus.wave_repelled.connect(func(_i: int) -> void: row["repelled"] += 1)
	sim.bus.colonist_died.connect(func(_id: int) -> void: row["dead"] += 1)
	var st := {"sid": -1, "ids": [], "hold": Vector2i(-1, -1), "wave": -1, "focus": -1}
	var total := days * sim.ticks_per_day
	var down_ticks := 0
	while sim.tick < total and sim.game_over_reason == "":
		if with_squad and sim.tick % ACT_PERIOD == 0:
			act(sim, st)
		sim.step()
		if sim.tick % 5 == 0:
			for c in sim.colonists.list:
				if c.alive and c.health != null and c.health.downed:
					down_ticks += 5
	row["down_sec"] = float(down_ticks) / float(Simulation.TICKS_PER_SECOND)
	row["waves"] = sim.threats.wave_index
	row["taint_pct"] = sim.contamination.fraction() * 100.0
	row["essence_spent"] = sim.ledger.get_count("ability:refined_essence") + int(sim.ledger.consumed.get("refined_essence", 0))
	row["essence_made"] = int(sim.ledger.produced.get("refined_essence", 0))
	row["over"] = sim.game_over_reason
	row["day"] = sim.day()
	row["hash"] = hash([row["repelled"], row["dead"], sim.tick, sim.contamination.level, sim.colonists.alive_count()])
	sim.dispose()
	if own_bus:
		bus.free()
	return row


static func _alive_ids(sim: Simulation) -> Array:
	var out: Array = []
	for c in sim.colonists.list:
		if c.alive and not (c.health != null and c.health.downed):
			out.append(c.id)
	return out


## Where the squad stands: a few cells from the capsule toward the side the wave comes from.
static func hold_cell(sim: Simulation) -> Vector2i:
	var center := sim.map_center()
	var o := sim.threats.next_spawn_origin
	var dir := Vector2.ZERO
	if o.x >= 0:
		dir = Vector2(o - center).normalized()
	var want := center + Vector2i(roundi(dir.x * 5.0), roundi(dir.y * 5.0))
	for r in range(0, 6):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var c := want + Vector2i(x, y)
				if maxi(absi(x), absi(y)) == r and sim.map.in_bounds(c) and sim.map.is_passable(c):
					return c
	return center


static func act(sim: Simulation, st: Dictionary) -> void:
	var real := sim.has_method("form_squad")
	var t := sim.threats
	var fighting := t.wave_active or (t.awakened and t.next_wave_tick - sim.tick < 120)
	if not fighting:
		if st["sid"] >= 0 or not (st["ids"] as Array).is_empty():
			_stand_down(sim, st, real)
		return
	if st["sid"] < 0 and (st["ids"] as Array).is_empty():
		var ids := _alive_ids(sim).slice(0, 3)
		if ids.is_empty():
			return
		st["ids"] = ids
		if real:
			var roles: Array = []
			for i in ids.size():
				roles.append(ROLES[i])
			st["sid"] = sim.form_squad(ids, roles)
		else:
			for id: int in ids:
				sim.set_drafted(id, true)
	var hold := hold_cell(sim)
	if hold != st["hold"] and not t.wave_active:
		st["hold"] = hold
		_hold(sim, st, hold, real)
	elif st["hold"] == Vector2i(-1, -1):
		st["hold"] = hold
		_hold(sim, st, hold, real)
	# Focus the enemy nearest to the hold cell.
	var best: Enemy = null
	var best_d := INF
	for e in t.enemies:
		if e.leaving:
			continue
		var d := Vector2(e.cell).distance_squared_to(Vector2(st["hold"]))
		if d < best_d:
			best_d = d
			best = e
	if best != null and best.id != st["focus"]:
		st["focus"] = best.id
		if real:
			sim.squad_focus(st["sid"], best.id)
		else:
			for id: int in st["ids"]:
				sim.order_attack(id, best.id)
	if real and sim.has_method("use_ability") and best != null:
		for a in ["taunt", "volley", "stabilise"]:
			sim.use_ability(st["sid"], a)  # rejected while on cooldown / without essence


static func _hold(sim: Simulation, st: Dictionary, hold: Vector2i, real: bool) -> void:
	if real:
		sim.squad_hold(st["sid"], hold)
	else:
		var i := 0
		for id: int in st["ids"]:
			sim.order_move(id, hold + Vector2i(i % 2, i / 2))
			i += 1


static func _stand_down(sim: Simulation, st: Dictionary, real: bool) -> void:
	if real and st["sid"] >= 0:
		sim.disband_squad(st["sid"])
	else:
		for id: int in st["ids"]:
			sim.set_drafted(id, false)
	st["sid"] = -1
	st["ids"] = []
	st["hold"] = Vector2i(-1, -1)
	st["focus"] = -1
