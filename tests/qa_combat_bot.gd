class_name QaCombatBot
extends RefCounted
## QA: a deterministic player that fights waves with ONE squad (Bulwark + Lancer + Medic, public
## commands only) versus the same colony with no squad (current behaviour: the alarm sends everyone
## hiding). Squad profile: forms the squad when a wave nears, holds BEHIND the turret that faces the
## wave, focuses the enemy nearest to the hold, taunts when a brute telegraphs a slam, volleys when
## something is in range, stabilises Down inmates, disbands when the wave is over.
## Both modes get the same refined_essence in a stockpile so abilities are payable.

const Scen := preload("res://tests/scenario.gd")
const ROLES := ["bulwark", "lancer", "medic"]
const ACT_PERIOD := 20
const ESSENCE := 12
const FOCUS_RADIUS := 22.0
const MIN_HP_FRAC := 0.7
const RETREAT_HP_FRAC := 0.3


## One game: `days` days on `seed_value`. Returns the table row.
static func run(seed_value: int, with_squad: bool, days := 25, turrets := 2, bus: Node = null) -> Dictionary:
	var own_bus := bus == null
	if own_bus:
		bus = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(seed_value, bus)
	sim.start_new_game()
	Scen.standard_colony(sim, turrets)
	var store := Scen.find_zone_spot(sim, sim.map_center() + Vector2i(5, 5), Vector2i(1, 1))
	sim.set_zone(store, "stockpile")
	sim.ledger.record_produced("refined_essence", ESSENCE, "test")
	sim.items.drop(store, "refined_essence", ESSENCE)
	var row := {"seed": seed_value, "squad": with_squad, "repelled": 0, "dead": 0, "down_sec": 0.0, "essence_spent": 0, "abilities": 0}
	sim.bus.ability_used.connect(func(_s: int, _a: String, _u: int) -> void: row["abilities"] += 1)
	sim.bus.wave_repelled.connect(func(_i: int) -> void: row["repelled"] += 1)
	var roles_seen := {}  # colonist id -> role, remembered at formation
	row["deaths"] = []  ## [tick, wave_index, squad role or "-"]
	sim.bus.colonist_died.connect(func(id: int) -> void:
		row["dead"] += 1
		row["deaths"].append([sim.tick, sim.threats.wave_index, str(roles_seen.get(id, "-"))]))
	var st := {"sid": -1, "ids": [], "hold": Vector2i(-1, -1), "focus": -1}
	var total := days * sim.ticks_per_day
	var down_ticks := 0
	while sim.tick < total and sim.game_over_reason == "":
		if with_squad and sim.tick % ACT_PERIOD == 0:
			act(sim, st)
			var sq0 := sim.squads.get_squad(int(st["sid"]))
			if sq0 != null:
				for mid: int in sq0.members:
					roles_seen[mid] = sq0.role_of.get(mid, "-")
		sim.step()
		if sim.tick % 5 == 0:
			for c in sim.colonists.list:
				if c.alive and c.health != null and c.health.downed:
					down_ticks += 5
	row["down_sec"] = float(down_ticks) / float(Simulation.TICKS_PER_SECOND)
	row["waves"] = sim.threats.wave_index
	row["taint_pct"] = sim.contamination.fraction() * 100.0
	row["essence_spent"] = row["abilities"]  # each ability costs 1 refined_essence
	row["essence_made"] = int(sim.ledger.produced.get("refined_essence", 0))
	row["over"] = sim.game_over_reason
	row["day"] = sim.day()
	row["hash"] = hash([row["repelled"], row["dead"], sim.tick, sim.contamination.level, sim.colonists.alive_count()])
	sim.dispose()
	if own_bus:
		bus.free()
	return row


## Healthiest first (ties by id); inmates under MIN_HP_FRAC stay out of the squad.
static func _alive_ids(sim: Simulation) -> Array:
	var cand: Array = []
	for c in sim.colonists.list:
		if c.alive and not (c.health != null and c.health.downed) and c.hp >= c.max_hp * MIN_HP_FRAC and sim.squads.squad_of(c.id) == null:
			cand.append([-c.hp, c.id])
	cand.sort()
	var out: Array = []
	for p: Array in cand:
		out.append(p[1])
	return out


## Behind the turret facing the wave: the turret nearest to the wave's origin, then 2 cells toward the
## capsule (so the turret stands between the squad and the creatures). No turret: a few cells out.
static func hold_cell(sim: Simulation) -> Vector2i:
	var center := sim.map_center()
	var o := sim.threats.next_spawn_origin
	var want := center
	var best := INF
	for b in sim.buildings.list:
		if b.def_id != "turret" or b.destroyed:
			continue
		var d := Vector2(b.cell).distance_squared_to(Vector2(o)) if o.x >= 0 else 0.0
		if d < best:
			best = d
			want = b.cell + Vector2i((Vector2(center - b.cell).normalized() * 2.0).round())
	for r in range(0, 6):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var c := want + Vector2i(x, y)
				if maxi(absi(x), absi(y)) == r and sim.map.in_bounds(c) and sim.map.is_passable(c):
					return c
	return center


static func act(sim: Simulation, st: Dictionary) -> void:
	var t := sim.threats
	var fighting := t.wave_active or (t.awakened and t.next_wave_tick >= 0 and t.next_wave_tick - sim.tick < 120)
	if not fighting:
		if st["sid"] >= 0:
			sim.disband_squad(st["sid"])
			st["sid"] = -1
			st["hold"] = Vector2i(-1, -1)
			st["focus"] = -1
		return
	if st["sid"] < 0:
		if sim.tick < int(st.get("retreat_until", 0)):
			return
		var ids := _alive_ids(sim).slice(0, 3)
		if ids.is_empty():
			return
		st["sid"] = sim.form_squad(ids, ROLES.slice(0, ids.size()))
		if st["sid"] < 0:
			return
	var sid: int = st["sid"]
	if sim.squads.get_squad(sid) == null:  # every member died
		st["sid"] = -1
		return
	var sq := sim.squads.get_squad(sid)
	var worst := 1.0
	for mid: int in sq.members:
		var mc := sim.colonists.get_by_id(mid)
		worst = minf(worst, mc.hp / mc.max_hp)
	if worst < RETREAT_HP_FRAC and not sim.threats.enemies.is_empty():  # pull back: inmates flee on alarm
		sim.disband_squad(sid)
		st["sid"] = -1
		st["hold"] = Vector2i(-1, -1)
		st["focus"] = -1
		st["retreat_until"] = sim.tick + 600
		return
	var hold := hold_cell(sim)
	if hold != st["hold"]:
		st["hold"] = hold
		sim.squad_hold(sid, hold)
	var best: Enemy = null
	var best_d := INF
	var slam := false
	for e in t.enemies:
		if e.leaving:
			continue
		var d := Vector2(e.cell).distance_squared_to(Vector2(st["hold"]))
		if d < best_d:
			best_d = d
			best = e
		if e.def_id == "brute" and e.has_meta("tg") and d <= 100.0:
			slam = true
	# Only enemies that came close to the hold are focused: focusing one at the map edge would make the
	# squad run out of turret cover. Otherwise the squad keeps its post (auto-fire from the anchor).
	if best != null and best_d > FOCUS_RADIUS * FOCUS_RADIUS:
		best = null
	if best != null and best.id != st["focus"]:
		st["focus"] = best.id
		sim.squad_focus(sid, best.id)
	elif best == null and st["focus"] >= 0:
		st["focus"] = -1
		sim.squad_hold(sid, hold)  # clears the focus, back to the post
	if slam:
		sim.use_ability(sid, "taunt")
	if best != null and best_d <= 81.0:
		sim.use_ability(sid, "volley")
	sim.use_ability(sid, "stabilise")  # rejected (no cost) while nobody is Down
