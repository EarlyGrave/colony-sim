class_name ThreatSystem
extends RefCounted
## Creature waves and turret defense.
##
## The threat wakes up once enough ore is mined or after the first refining
## batch. Waves then come on a timer; their strength grows with the wave
## number, the total refined essence and planet contamination
## (data/balance.json "threat"). Creatures spawn at a map edge, go for key
## buildings (by `threat_priority`), and maul colonists caught in the open.

var sim: Simulation
var cfg: Dictionary
var awakened := false
var next_wave_tick := -1
var wave_index := 0
var wave_active := false
var wave_end_tick := 0
## Where the next wave will come from; decided when the wave is scheduled.
var next_spawn_origin := Vector2i(-1, -1)
var _warned := false
## Current raid (see data/raids.json); "" when no wave is active.
var raid_id := ""
var raid_total := 0
var raid_dead := 0
var retreating := false
## Tests / scenarios: force the next raid type regardless of points.
var force_raid_id := ""
## Burrowers waiting for the tremor to end: {tick, building, cell, units}.
var pending_drop: Dictionary = {}
var enemies: Array[Enemy] = []
var kills := 0
## Recent turret shots for the view: [from: Vector2, to: Vector2, tick: int]
var shots: Array = []
var _next_id := 1
var _alarm_before_wave := false
## Own stream for raid type/composition/origin (D24): the same seed brings the same
## waves whatever the player does, so play-style comparisons are not luck.
var wave_rng := RandomNumberGenerator.new()
# region Q2
## One-shot spawn override for the Pilgrims quest. Held in an object so the golden state dump is unchanged.
class Q2Spawn:
	extends RefCounted
	var cell := Vector2i(-1, -1)  ## pending override origin (x < 0 = none)

var q2 := Q2Spawn.new()


## Arms the next wave to spawn at `cell`, `delay_ticks` later than planned. Clears itself when that wave starts.
func q2_arm(cell: Vector2i, delay_ticks: int) -> void:
	q2.cell = cell
	next_spawn_origin = cell
	if next_wave_tick >= 0:
		next_wave_tick += delay_ticks
# endregion
# region perf-threat
## Enemies by cell bucket, for turret / combat range queries.
var hash: SpatialHash
## Times an enemy re-evaluated its target (test / bench counter).
var retarget_count := 0
## region W2d: hot-loop scalars. Held in an object so the golden state dump (script variables of this system) is unchanged.
class Hot:
	extends RefCounted
	var retarget_n := 20  ## cfg retarget_ticks
	var bite_ok := true  ## belts exist and line damage is on (per tick; _attack_structure re-checks)
	var line_on := true  ## balance line_damage.enabled, per tick
	var kind := ""  ## region F2: def id of that enemy
	var objective: RaidObjective = null  ## region RO: current raid objective (held here to keep the golden dump unchanged)
	var cause := "generic"  ## region F2: what killed the enemy being announced (read by the view during enemy_killed only)
var _hot := Hot.new()
# endregion
# region T1
var model: ThreatModel
## Attention-based targeting (data/threat.json "enabled"); false = legacy priority/distance scan.
var threat_v2 := false
# endregion


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.balance["threat"]
	hash = SpatialHash.new(int(cfg.get("hash_bucket", 8)))  # region perf-threat
	_hot.retarget_n = maxi(1, int(cfg["retarget_ticks"]))  # region W2d
	model = ThreatModel.new(sim)  # region T1
	threat_v2 = bool(sim.defs.threat.get("enabled", false))  # region T1
	wave_rng.seed = sim.seed_value ^ 0x57A7E
	sim.listen(sim.bus.first_refine_done, awaken)
	sim.listen(sim.bus.first_refine_done, _rv_on_first_refine)  # region RV
	sim.listen(sim.bus.item_mined, _on_item_mined)
	_k1_init()  # region K1
	_sc_init()  # region SC
	set_meta("metro", MetroTrack.new(sim))  # region MT: meta keeps the golden state dump unchanged


func _on_item_mined(_c: Vector2i, _item: String, _n: int) -> void:
	if not awakened and sim.ledger.get_count("mining:essence_ore") >= int(cfg["awaken_mined_total"]):
		awaken()


func awaken() -> void:
	if awakened or not bool(cfg.get("enabled", true)):
		return
	awakened = true
	next_wave_tick = sim.tick + int(float(cfg["first_wave_delay_days"]) * sim.ticks_per_day)
	_schedule_origin()
	sim.bus.threat_awakened.emit()


## Wealth of the colony: stored items, building costs and colonists.
func colony_wealth() -> float:
	var w := 0.0
	for item: String in sim.defs.items:
		w += float(sim.defs.items[item].get("value", 0.0)) * sim.items.count_world(item)
	for b in sim.buildings.list:
		for item: String in b.def.get("cost", {}):
			w += float(sim.defs.items.get(item, {}).get("value", 0.0)) * int(b.def["cost"][item])
	return w + float(cfg["colonist_value"]) * sim.colonists.alive_count()


## Raid points: the colony's wealth and growth is what calls the creatures.
func raid_points(index: int) -> float:
	return sim.contraband.wave_mult() * _o3_mult() * _b2_clean_mult() * _attract_mult() * sim.crises.mult("raid_points_mult") * (float(cfg["base_strength"]) \
		+ float(cfg["per_wave"]) * (index - 1) \
		+ float(cfg["per_wealth"]) * colony_wealth() \
		+ float(cfg["per_refined"]) * sim.ledger.get_count("recipe:refined_essence") \
		+ float(cfg["per_contamination"]) * sim.contamination.level)


# region O3
## Difficulty preset multiplier (start opt wave_mult); exactly 1.0 when absent.
func _o3_mult() -> float:
	return float(sim.opts.get("wave_mult", 1.0)) * sim.quests.mod("wave_mult")  # region Q0: 1.0 unless a quest set it
# endregion


## Perk threat_attract: mean over living colonists, applied to the whole raid budget.
func _attract_mult() -> float:
	var sum := 0.0
	var n := 0
	for c in sim.colonists.list:
		if c.alive:
			sum += sim.perks.mod(c, "threat_attract")
			n += 1
	return maxf(0.0, 1.0 + sum / float(n)) if n > 0 else 1.0


## Kept API name (balance_report, tests).
func wave_strength(index: int) -> float:
	return raid_points(index)


## Weighted pick among raid types whose min_points the budget reaches.
func pick_raid_type(points: float) -> String:
	var ids: Array[String] = []
	var total := 0.0
	for id: String in sim.defs.raids:
		var r: Dictionary = sim.defs.raids[id]
		if float(r["min_points"]) <= points and not r.get("scripted", false) and r.get("faction", "creature") == "creature":  # region O1 + MT
			ids.append(id)
			total += float(r["weight"])
	if ids.is_empty():
		return ""
	var roll := wave_rng.randf() * total
	for id in ids:
		roll -= float(sim.defs.raids[id]["weight"])
		if roll < 0.0:
			return id
	return ids[-1]


## Spends `points` on units of the raid type; returns enemy ids in spawn order.
func compose_raid(id: String, points: float) -> Array[String]:
	if sim.defs.raids[id].has("fixed"):  # region O1: scripted raid, no rng
		var fixed: Array[String] = []
		for u: Variant in sim.defs.raids[id]["fixed"]:
			fixed.append(str(u))
		return fixed
	var units: Array = sim.defs.raids[id]["units"]
	var out: Array[String] = []
	var budget := points
	for guard in 200:
		var opts: Array = []
		var total := 0.0
		for u: Dictionary in units:
			if float(sim.defs.enemies[u["enemy"]]["threat_cost"]) <= budget:
				opts.append(u)
				total += float(u["weight"])
		if opts.is_empty():
			break
		var roll := wave_rng.randf() * total
		var pick: Dictionary = opts[-1]
		for u: Dictionary in opts:
			roll -= float(u["weight"])
			if roll < 0.0:
				pick = u
				break
		budget -= float(sim.defs.enemies[pick["enemy"]]["threat_cost"])
		out.append(str(pick["enemy"]))
	return out


func tick() -> void:
	var held := sim.tutorial != null and sim.tutorial.waves_held()  # region O1
	if not held:  # region MT
		metro().tick()
	_k1_tick(held)  # region K1
	if awakened and not wave_active and not held and sim.tick >= next_wave_tick and _rv_gate_ok() and sim.tick >= _k1_calm_until and sim.tick >= dormant_until:  # region K1 + SC
		start_wave()
	if awakened and not wave_active and not held and not _warned \
			and next_wave_tick - sim.tick < int(cfg["warning_ticks"]) + sim.idle_work.warning_bonus():  # region idle-work
		_warned = true
		sim.bus.wave_incoming.emit(next_spawn_origin, next_wave_tick - sim.tick)
	sim.pathfinder.advance_flows(int(cfg.get("flow_cells_per_tick", 6000)))  # region perf-threat
	_ro_tick()  # region RO
	_tick_turrets()
	_hot.line_on = bool(sim.defs.balance["line_damage"]["enabled"])  # region W2d
	_hot.bite_ok = _hot.line_on and sim.logistics.belts.belt_count > 0
	var ei := 0  # region E5: index walk instead of enemies.duplicate(); only _tick_leaving erases (same order)
	while ei < enemies.size():
		var e: Enemy = enemies[ei]
		ei += 1
		var before := e.cell  # region perf-threat
		if e.leaving:
			var n0 := enemies.size()
			_tick_leaving(e)
			if enemies.size() < n0:
				ei -= 1
		elif not (_hot.objective != null and _hot.objective.gorge_step(sim, e)):  # region RO
			_tick_enemy(e)
		if e.cell != before and hash.has(e):  # region perf-threat
			hash.update(e)
	if wave_active and not pending_drop.is_empty() and sim.tick >= int(pending_drop["tick"]):
		_do_drop()
	if wave_active and (_attackers() == 0 and pending_drop.is_empty() or sim.tick >= wave_end_tick):
		end_wave()
	while not shots.is_empty() and sim.tick - int(shots[0][2]) > 3:
		shots.pop_front()


# region O1
## True if the current raid is data-flagged with `flag` (scripted tutorial audit).
func _scripted(flag: String) -> bool:
	return raid_id != "" and bool(sim.defs.raids.get(raid_id, {}).get(flag, false))


## Tutorial: arm the scripted audit `delay` ticks from now (warning fires at once).
func schedule_scripted(delay: int) -> void:
	awaken()
	force_raid_id = "tutorial_audit"
	next_wave_tick = sim.tick + delay
	_schedule_origin()
# endregion


# region LD
## Origin lives in object meta (not a script var) so state dumps/goldens stay unchanged.
func _lockdown_origin() -> Vector2i:
	return get_meta("lockdown_origin", Vector2i(-1, -1))


## True when `cell` must hide: manual alarm = everybody; raid alarm = inside
## `lockdown_radius` of the raid origin, or any live enemy within aggro range.
func in_lockdown(cell: Vector2i) -> bool:
	if not sim.alarm:
		return false
	var radius := float(sim.defs.threat.get("lockdown_radius", 0))
	if sim.alarm_manual or radius <= 0.0 or _lockdown_origin().x < 0:
		return true
	var p := Vector2(cell)
	if p.distance_to(Vector2(_lockdown_origin())) <= radius:
		return true
	var aggro := float(cfg["colonist_aggro_range"])
	for e in enemies:
		if Vector2(e.cell).distance_to(p) <= aggro + 1.0:
			return true
	return false
# endregion


## Metropolis tech track (region MT).
func metro() -> MetroTrack:
	return get_meta("metro") as MetroTrack


func start_wave(strength_mult: float = 1.0) -> void:  # region EN2
	wave_index += 1
	wave_active = true
	wave_end_tick = sim.tick + int(cfg["wave_duration_ticks"])
	var strength := raid_points(wave_index)
	_k1_audit_now_wave = _k1_audit_now  # region K1
	if _k1_audit_now:
		strength = _k1_audit_points
	strength *= sim.contracts.take_raid_mult()  # region contracts
	strength *= strength_mult  # region EN2
	var metro_raid := has_meta("metro_points")  # region MT
	if metro_raid:
		strength = float(get_meta("metro_points"))
	if wave_index == 1 and not metro_raid:
		strength = minf(strength, float(cfg["first_wave_max_points"]))  # tutorial swarm
	var origin := next_spawn_origin if next_spawn_origin.x >= 0 else _pick_spawn_origin()
	if q2.cell.x >= 0:  # region Q2: the prayer wave comes to the dump, once
		origin = q2.cell
		q2.cell = Vector2i(-1, -1)
	sim.ecology.wave_nest = sim.ecology.nest_at(origin) if sim.ecology.active() else -1  # region T5
	raid_id = (force_raid_id if force_raid_id != "" else pick_raid_type(strength)) if origin.x >= 0 else ""
	raid_total = 0
	raid_dead = 0
	retreating = false
	pending_drop = {}
	if raid_id != "" and sim.defs.raids[raid_id].has("wave_ticks"):  # region O1
		wave_end_tick = sim.tick + int(sim.defs.raids[raid_id]["wave_ticks"])
	if raid_id != "":
		var r: Dictionary = sim.defs.raids[raid_id]
		var units := compose_raid(raid_id, strength)
		if not r.has("fixed"):  # region O1
			units = sim.ecology.muster(units)  # region T5
		raid_total = units.size()
		if str(r["spawn"]) == "drop" and not sim.buildings.list.is_empty():
			var b: Building = sim.buildings.list[sim.rng.randi_range(0, sim.buildings.list.size() - 1)]
			var ticks := int(r["tremor_ticks"])
			pending_drop = {"tick": sim.tick + ticks, "building": b.id, "cell": b.cell, "units": units}
			sim.bus.raid_tremor.emit(b.cell, ticks, str(r.get("warning_text", "")))
		else:
			for id in units:
				_spawn(id, _spawn_cell_near(origin))
		_ro_roll(r)  # region RO
		sim.bus.raid_started.emit(raid_id, strength, raid_total)
	_alarm_before_wave = sim.alarm
	set_meta("lockdown_origin", origin)  # region LD
	sim._alarm_raid(true)
	sim.bus.wave_started.emit(wave_index, strength)


## Burrowers surface around the targeted building after the tremor.
func _do_drop() -> void:
	var d := pending_drop
	pending_drop = {}
	var r: Dictionary = sim.defs.raids[raid_id]
	var center: Vector2i = d["cell"]
	var b := sim.buildings.get_by_id(int(d["building"]))
	if b != null:
		center = b.cell
	var scatter := int(r.get("drop_scatter", 2))
	for id: String in d["units"]:
		var c := center
		for attempt in 16:
			var t := center + Vector2i(sim.rng.randi_range(-scatter, scatter), sim.rng.randi_range(-scatter, scatter))
			if sim.map.is_passable(t) and not sim.buildings.occupied(t):
				c = t
				break
		_spawn(id, c)
	sim.bus.raid_burrowed.emit(center, (d["units"] as Array).size())


## Morale-lite: when too many fall the survivors turn back.
func _check_morale() -> void:
	if retreating or raid_id == "" or raid_total <= 0 or not pending_drop.is_empty():
		return
	var frac := float(sim.defs.raids[raid_id].get("retreat_fraction", cfg["retreat_fraction"]))
	if float(raid_dead) / float(raid_total) > frac:
		_begin_retreat()  # region RO


# region RO
## Raid objectives (sim/threats/raid_objective.gd). Off unless balance threat.raid_objectives.
func get_objective() -> RaidObjective:
	return _hot.objective


func _begin_retreat() -> void:
	retreating = true
	for e in enemies:
		e.leaving = true
		e.clear_path()
	sim.bus.raid_retreat.emit(raid_id)


func _ro_roll(r: Dictionary) -> void:
	_hot.objective = null
	if not bool(cfg.get("raid_objectives", false)) or not r.has("objective") or r.has("fixed"):
		return
	_hot.objective = RaidObjective.make(sim, r, RaidObjective.roll(r, wave_rng))
	if _hot.objective.kind == "wreck":
		if not sim.bus.building_broken.is_connected(_ro_on_building):
			sim.bus.building_broken.connect(_ro_on_building)
			sim.bus.building_destroyed.connect(_ro_on_building)


func _ro_on_building(id: int) -> void:
	if _hot.objective != null and _hot.objective.kind == "wreck" and id == _hot.objective.target_id:
		_hot.objective.met = true


func _ro_tick() -> void:
	if _hot.objective == null or not wave_active or retreating or not _hot.objective.met:
		return
	sim.bus.raid_objective_met.emit(raid_id, _hot.objective.kind)
	_begin_retreat()
# endregion


func end_wave() -> void:
	var was_metro: bool = wave_active and str(sim.defs.raids.get(raid_id, {}).get("faction", "creature")) == "metropolis"  # region MT
	var repelled := wave_active and _attackers() == 0 and pending_drop.is_empty()
	var sc_audit := _k1_audit_now_wave  # region SC
	if wave_active and _scripted("scripted"):  # region O1: the audit always counts as repelled
		repelled = true
	wave_active = false
	raid_id = ""
	_hot.objective = null  # region RO
	pending_drop = {}
	for e in enemies:
		e.leaving = true
		e.clear_path()
	var k1_keep := next_wave_tick if _k1_audit_now_wave else -1  # region K1: an audit does not reset the pollution timer
	_k1_audit_now_wave = false
	next_wave_tick = sim.tick + int(float(cfg["wave_interval_days"]) * _k1_interval_mult * _k1_pollution_mult() * sc_mult() * sim.crises.mult("raid_interval_mult") * sim.ticks_per_day)
	if k1_keep >= 0:  # region K1
		next_wave_tick = maxi(k1_keep, sim.tick + 1)
	else:
		_k1_base_tick = sim.tick
	_schedule_origin()
	sim._alarm_raid(_alarm_before_wave)  # region LD
	_k1_wave_over()  # region K1
	if not was_metro:  # region MT
		metro().on_creature_wave_end()
	sim.bus.wave_ended.emit(wave_index)
	if repelled and not sc_audit:
		_sc_dormancy()  # region SC
	if repelled:
		sim.bus.wave_repelled.emit(wave_index)  # region progression


# region K1
## Pacing (data/balance.json "pacing"): calm after a hit + sentence-audit floor clock. Active only when the
## start opts carry preset pacing (audit_days), so plain sims are unchanged.
var _k1_audit_days := 0.0
var _k1_calm_mult := 1.0
var _k1_interval_mult := 1.0
var _k1_audit_at := -1
var _k1_audit_now := false
var _k1_audit_now_wave := false
var _k1_audit_points := 0.0
var _k1_calm_until := 0
var _k1_hit := false
var _k1_base_tick := -1  # end of the last pollution wave; the pollution countdown is re-scaled from it


func _k1_init() -> void:
	_k1_audit_days = float(sim.opts.get("audit_days", 0.0))
	if _k1_audit_days <= 0.0:
		return
	_k1_calm_mult = float(sim.opts.get("calm_mult", 1.0))
	_k1_interval_mult = float(sim.opts.get("wave_interval_mult", 1.0))
	_k1_audit_at = int(_k1_audit_days * sim.ticks_per_day)
	sim.listen(sim.bus.colonist_died, func(_id: int) -> void: _k1_hit = _k1_hit or wave_active)
	sim.listen(sim.bus.building_broken, func(_id: int) -> void: _k1_hit = _k1_hit or wave_active)


## Tick of the next sentence audit; -1 when pacing is off.
func next_audit_tick() -> int:
	return _k1_audit_at


## Days (float) until the next audit; -1.0 when pacing is off.
func days_to_audit() -> float:
	return -1.0 if _k1_audit_at < 0 else maxf(0.0, float(_k1_audit_at - sim.tick) / float(sim.ticks_per_day))


## Pollution drives the pollution-wave cadence: a clean planet stretches the interval, a dirty one shrinks it
## (balance.json pacing.pollution_interval). 1.0 when pacing is off.
func _k1_pollution_mult() -> float:
	if _k1_audit_at < 0:
		return 1.0
	var pi: Dictionary = sim.defs.balance.get("pacing", {}).get("pollution_interval", {})
	if pi.is_empty():
		return 1.0
	var t := clampf((sim.contamination.fraction() - float(pi["lo"])) / (float(pi["hi"]) - float(pi["lo"])), 0.0, 1.0)
	return lerpf(float(pi["clean_mult"]), float(pi["dirty_mult"]), t)


func _k1_tick(held: bool) -> void:
	if _k1_audit_at < 0 or not bool(cfg.get("enabled", true)):
		return
	if _k1_base_tick >= 0 and awakened and not wave_active and not held and sim.tick % 30 == 0:
		var iv := int(float(cfg["wave_interval_days"]) * _k1_interval_mult * _k1_pollution_mult() * sc_mult() * sim.crises.mult("raid_interval_mult") * sim.ticks_per_day)
		next_wave_tick = maxi(_k1_base_tick + iv, sim.tick + 1)
	if sim.tick >= _k1_audit_at and not wave_active and not held and not _k1_audit_now:
		var pc: Dictionary = sim.defs.balance.get("pacing", {})
		_k1_audit_points = float(pc.get("floor_pts_per_day", 0.7)) * _k1_audit_days * _o3_mult()
		_k1_audit_at = sim.tick + int((_k1_audit_days + sim.milestones.e3_audit_bonus_days()) * sim.ticks_per_day)  # region E3
		if sim.milestones.k2_consume_decoy():  # region K2: an outpost absorbs this audit
			return
		_k1_audit_now = true
		start_wave()
		_k1_audit_now = false


func _k1_wave_over() -> void:
	if _k1_hit:
		_k1_hit = false
		var pc: Dictionary = sim.defs.balance.get("pacing", {})
		_k1_calm_until = sim.tick + int(float(pc.get("calm_after_hit_days", 2.0)) * _k1_calm_mult * sim.ticks_per_day)
# endregion


func _attackers() -> int:
	var n := 0
	for e in enemies:
		if not e.leaving:
			n += 1
	return n


# --- Spawning -----------------------------------------------------------------

func _schedule_origin() -> void:
	_warned = false
	next_spawn_origin = _pick_spawn_origin()


## Compass side of a map cell relative to the map center: "north", "south", ...
func side_name(c: Vector2i) -> String:
	var d := c - sim.map_center()
	if absi(d.x) >= absi(d.y):
		return "east" if d.x > 0 else "west"
	return "south" if d.y > 0 else "north"


func _pick_spawn_origin() -> Vector2i:
	var o := _pick_edge_origin()
	# region T5: waves leave from the fullest nest (edge pick above still consumes wave_rng)
	if o.x >= 0 and sim.ecology.active():
		return sim.ecology.lead_cell()
	# endregion
	return o


func _pick_edge_origin() -> Vector2i:
	var home := sim.map_center()
	var w := sim.map.width
	var h := sim.map.height
	for attempt in 200:
		var side := wave_rng.randi_range(0, 3)
		var t := wave_rng.randi_range(0, (w if side < 2 else h) - 1)
		var c: Vector2i
		match side:
			0: c = Vector2i(t, 0)
			1: c = Vector2i(t, h - 1)
			2: c = Vector2i(0, t)
			_: c = Vector2i(w - 1, t)
		if sim.pathfinder.reachable_terrain(c, home):  # walls don't stop a wave from coming
			return c
	# Deterministic fallback: first reachable edge cell.
	for x in w:
		for y in [0, h - 1]:
			if sim.pathfinder.reachable(Vector2i(x, y), home):
				return Vector2i(x, y)
	for y in h:
		for x in [0, w - 1]:
			if sim.pathfinder.reachable(Vector2i(x, y), home):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _spawn_cell_near(origin: Vector2i) -> Vector2i:
	var r := int(cfg["spawn_scatter"])
	for attempt in 12:
		var c := origin + Vector2i(sim.rng.randi_range(-r, r), sim.rng.randi_range(-r, r))
		if sim.pathfinder.reachable_terrain(c, origin):
			return c
	return origin


func _spawn(def_id: String, c: Vector2i) -> Enemy:
	var e := Enemy.new(_next_id, def_id, sim.defs.enemies[def_id], c)
	_next_id += 1
	enemies.append(e)
	hash.insert(e)  # region perf-threat
	# region T5: mutant variant by nest pollution
	var vid := sim.ecology.roll_variant(e.def, sim.ecology.wave_nest)
	if vid != "":
		var v: Dictionary = e.def["variants"][vid]
		e.variant = vid
		e.max_hp *= float(v.get("hp_mult", 1.0))
		e.hp = e.max_hp
		e.damage_mult = float(v.get("damage_mult", 1.0))
		e.move_ticks = maxi(1, e.move_ticks + int(v.get("move_ticks_delta", 0)))
	# endregion
	# region mutation: creatures born on mutated ground are tougher
	if sim.mutation.is_mutated(c):
		e.max_hp *= 1.0 + float(sim.defs.mutation["enemy_hp_bonus"])
		e.hp = e.max_hp
	# endregion
	return e


# --- Enemy behaviour -------------------------------------------------------------

func _tick_enemy(e: Enemy) -> void:
	e.attack_cd = maxi(0, e.attack_cd - 1)
	if e.winding:  # region C3: winding up, stand still
		_c3_wind(e)
		return
	var biting := e.structure_dmg > 0.0 and _hot.bite_ok and _attack_structure(e)  # region T3
	if biting and e.target_kind == Enemy.Target.NONE:
		return
	if sim.tick >= e.retarget_at or not ((e.target_kind == Enemy.Target.BUILDING and e.target_b != null and not e.target_b.destroyed) or _target_valid(e)):
		_choose_target(e)
		retarget_count += 1  # region perf-threat
		e.retarget_at = _next_retarget(e)  # region perf-threat
	if e.target_kind == Enemy.Target.NONE:
		return
	var range_ := e.attack_range
	if e.target_kind == Enemy.Target.BELT:  # region R3X: _attack_structure does the biting
		if Vector2(e.target_cell).distance_to(Vector2(e.cell)) <= 1.0:
			e.clear_path()
		elif _approach_cell(e, e.target_cell) == GridMover.Move.FAILED:
			e.retarget_at = sim.tick + 5
		return
	if e.target_kind == Enemy.Target.BUILDING:
		var b := e.target_b  # region perf-threat
		if e.rc_b != b or e.rc_cell != e.cell:  # region W2d: a building never moves, so the range test only changes with the cell
			e.rc_b = b
			e.rc_cell = e.cell
			e.rc_in = b.distance_to(Vector2(e.cell)) <= range_
		if e.rc_in:
			e.clear_path()
			if e.attack_cd == 0 and _c3_begin(e, b.nearest_cell_to(e.cell)):  # region C3
				pass
			elif e.attack_cd == 0:
				e.attack_cd = int(e.def["attack_cooldown_ticks"])
				if not (b.def.get("critical", false) and _scripted("hq_immune")):  # region O1
					sim.buildings.damage(b, float(e.def["damage"]) * e.damage_mult * sim.mutation.enemy_damage_mult(e.cell))
		elif _approach_building(e, b) == GridMover.Move.FAILED:
			e.retarget_at = sim.tick + 5
	else:
		var c := e.target_c  # region perf-threat
		if Vector2(c.cell).distance_to(Vector2(e.cell)) <= range_:
			e.clear_path()
			if e.attack_cd == 0 and _c3_begin(e, c.cell):  # region C3
				pass
			elif e.attack_cd == 0:
				e.attack_cd = int(e.def["attack_cooldown_ticks"])
				# region perks: dodge_chance avoids melee hits
				var dodge := sim.perks.mod(c, "dodge_chance")
				if dodge > 0.0 and not e.def.get("ranged", false) and sim.rng.randf() < dodge:
					return
				# endregion
				if _scripted("colonist_harmless"):  # region O1
					return
				sim.health.apply_damage(c, sim.combat.resolve_hit(e.att_stats, sim.combat.def_of(c), float(e.def["damage"]) * e.damage_mult * sim.mutation.enemy_damage_mult(e.cell), str(e.def.get("dmg_type", "phys"))), "", str(e.def.get("damage_kind", "bite")))  # region health + E1
		elif _approach_colonist(e, c) == GridMover.Move.FAILED:  # region perf-threat
			e.retarget_at = sim.tick + 5


func _tick_leaving(e: Enemy) -> void:
	if _leave_step(e) != GridMover.Move.MOVING:  # region perf-threat
		enemies.erase(e)
		hash.remove(e)


func _target_valid(e: Enemy) -> bool:
	match e.target_kind:
		Enemy.Target.BUILDING:
			return e.target_b != null and not e.target_b.destroyed  # region perf-threat
		Enemy.Target.COLONIST:
			var c := e.target_c  # region perf-threat
			return c != null and c.alive and not c.hidden
		Enemy.Target.BELT:  # region R3X
			return sim.logistics.belts.has_belt(e.target_cell) and sim.logistics.belts.hp_at(e.target_cell) > 0.0
	return false


func _choose_target(e: Enemy) -> void:
	if threat_v2:  # region T1
		_choose_target_v2(e)
		return
	var pos := Vector2(e.cell)
	# 1) Colonists caught in the open nearby.
	var best_d := float(cfg["colonist_aggro_range"])
	e.target_kind = Enemy.Target.NONE
	for c in sim.colonists.list:
		if c.alive and not c.hidden:
			var d := Vector2(c.cell).distance_to(pos)
			if d <= best_d and sim.pathfinder.can_approach(e.cell, c.cell):
				best_d = d
				e.target_kind = Enemy.Target.COLONIST
				e.target_id = c.id
				e.target_c = c  # region perf-threat
	if e.target_kind != Enemy.Target.NONE:
		return
	# 2) A turret shooting at us; 3) the most valuable building.
	var best: Building = null
	var best_score := -INF
	for b in sim.buildings.list:
		if b.def.get("sapper_only", false):  # walls are only attacked when they block the way
			continue
		var d := b.distance_to(pos)
		var score: float
		if b.def.has("turret") and d <= float(cfg["turret_aggro_range"]):
			score = float(cfg["turret_target_bonus"]) - d
		else:
			score = float(b.def.get("threat_priority", 0)) * float(cfg["priority_weight"]) - d
		if score > best_score:
			best_score = score
			best = b
	if best != null:
		e.target_kind = Enemy.Target.BUILDING
		e.target_id = best.id
		e.target_b = best  # region perf-threat
		if not sim.pathfinder.can_approach(e.cell, best.nearest_cell_to(e.cell)):
			_sapper_target(e)


func damage_enemy(e: Enemy, amount: float, cause := "generic", by: Colonist = null) -> void:  # region F2 (cosmetic cause) + F3 (kill credit)
	e.hp -= amount
	if e.hp <= 0.0 and enemies.has(e):
		enemies.erase(e)
		hash.remove(e)  # region perf-threat
		kills += 1
		if wave_active:
			raid_dead += 1
			_check_morale()
		_hot.cause = cause  # region F2
		_hot.kind = e.def_id  # region F2
		if by != null:  # region F3
			sim.colonists.add_kill(by, e.def_id)
			sim.colonists.record_changed(by)
		if sim.quests != null and sim.quests.is_started():  # LN: Q8 Study doubles the essence a kill yields (base 1 ore, only while the mod runs)
			var extra := roundi(float(sim.defs.balance.get("creature_essence_base", 1)) * (sim.quests.mod("essence_drop_mult") - 1.0))
			if extra > 0:
				sim.ledger.record_produced("essence_ore", extra, "creature")
				sim.items.drop(e.cell, "essence_ore", extra)
		sim.bus.enemy_killed.emit(e.id)
		_hot.cause = "generic"  # region F2


# region F2
## Cause of the kill being announced (valid inside an enemy_killed handler, else "generic").
func last_kill_cause() -> String:
	return _hot.cause


func last_kill_kind() -> String:
	return _hot.kind
# endregion


# --- Turrets ------------------------------------------------------------------------

func _tick_turrets() -> void:
	for b: Building in sim.buildings.list.duplicate():
		if not b.def.has("turret") or b.broken:
			continue
		b.turret_cooldown = maxi(0, b.turret_cooldown - 1)
		if b.turret_cooldown > 0:
			continue
		var t: Dictionary = b.def["turret"]
		var from: Vector2 = b.center()
		var target: Enemy = null
		var best_d := float(t["range"])
		var range_max := best_d  # region T3
		# region perf-threat: nearest in range; ties go to the newest (same as the old full scan)
		var mode := sim.get_rule_mode("turret_target_mode")  # region T3
		for e: Enemy in hash.query(from, best_d):
			if e.leaving:
				continue
			var d := Vector2(e.cell).distance_to(from)
			if d > range_max:  # region T3
				continue
			if mode != "nearest" and mode != "":  # region T3
				if target == null or _turret_prefers(mode, e, target, d, best_d):
					best_d = d
					target = e
			elif d < best_d or (d == best_d and (target == null or e.id > target.id)):
				best_d = d
				target = e
		# endregion
		if target == null:
			continue
		if sim.ammo != null and not sim.ammo.turret_try_fire(b, best_d):  # region ammo
			continue
		b.turret_cooldown = int(t["cooldown_ticks"])
		shots.append([from, target.visual_pos(), sim.tick])
		damage_enemy(target, float(t["damage"]), "turret")  # region F2
		sim.buildings.wear(b, float(b.def.get("wear_per_shot", 0.0)))

# region combat
## Living (not leaving) enemies within `r` cells of `pos`, nearest first.
func enemies_in_range(pos: Vector2, r: float) -> Array[Enemy]:
	var found: Array = []
	for e: Enemy in hash.query(pos, r):
		if not e.leaving:
			found.append([Vector2(e.cell).distance_to(pos), e.id, e])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array[Enemy] = []
	for f: Array in found:
		out.append(f[2])
	return out

# region construction
## Walks toward a building; a solid target (wall) is approached from a free neighbour.
func _approach_building(e: Enemy, b: Building) -> int:
	var pf := sim.pathfinder
	var f := pf.flow_cached(b.id)
	if f == null:
		var sources: Array[Vector2i] = []
		for p in b.footprint():
			for s in pf.approach_cells(p):
				if not sources.has(s):
					sources.append(s)
		if sources.is_empty():
			return GridMover.Move.FAILED
		f = pf.flow_to(b.id, sources)
	return e.move_flow(f, sim)


## Sapper-lite: the real target is walled off, so chew through the nearest wall
## the creature can actually reach.
func _sapper_target(e: Enemy) -> void:
	var best: Building = null
	var best_d := INF
	for b in sim.buildings.list:
		if not b.def.get("blocks_movement", false):
			continue
		var d := b.distance_to(Vector2(e.cell))
		if d < best_d and sim.pathfinder.can_approach(e.cell, b.cell):
			best = b
			best_d = d
	if best != null:
		e.target_kind = Enemy.Target.BUILDING
		e.target_id = best.id
		e.target_b = best  # region perf-threat
# endregion

# region perf-threat
## Flow cache key spaces (building ids are small).
const FLOW_CELL := 1 << 30
const FLOW_LEAVE := 1 << 31

## Next re-target tick: one slot every `retarget_ticks`, phase = id % retarget_ticks.
func _next_retarget(e: Enemy) -> int:
	var n := _hot.retarget_n
	return sim.tick + n - posmod(sim.tick - e.id, n)


## Chase a colonist along a small bounded field around their current cell.
func _approach_colonist(e: Enemy, c: Colonist) -> int:
	return _approach_cell(e, c.cell)


func _approach_cell(e: Enemy, cell: Vector2i) -> int:
	var pf := sim.pathfinder
	var key := FLOW_CELL + cell.y * sim.map.width + cell.x
	var f := pf.flow_cached(key)
	if f == null:
		var sources := pf.approach_cells(cell)
		if sources.is_empty():
			return GridMover.Move.FAILED
		f = pf.flow_to(key, sources, int(cfg.get("chase_flow_radius", 16)))
	return e.move_flow(f, sim)


## Survivors walk back to the (4x4 block around the) cell they spawned at.
func _leave_step(e: Enemy) -> int:
	var pf := sim.pathfinder
	var bx := e.spawn_cell.x / 4 * 4
	var by := e.spawn_cell.y / 4 * 4
	var key := FLOW_LEAVE + by * sim.map.width + bx
	var f := pf.flow_cached(key)
	if f == null:
		var sources: Array[Vector2i] = []
		for y in 4:
			for x in 4:
				var p := Vector2i(bx + x, by + y)
				if pf.is_walkable(p):
					sources.append(p)
		if sources.is_empty():
			return GridMover.Move.FAILED
		f = pf.flow_to(key, sources)
	return e.move_flow(f, sim)
# endregion

# region T1
## Best target by attention score (see ThreatModel.pick): {kind: "building"|"colonist", id: int} or {}.
func pick_target(e: Enemy) -> Dictionary:
	return model.pick(e)


func _choose_target_v2(e: Enemy) -> void:
	var t := model.pick(e)  # region W2d: = pick_target(e)
	e.target_kind = Enemy.Target.NONE
	if t.is_empty():
		return
	if t["kind"] == "belt":  # region R3X
		e.target_kind = Enemy.Target.BELT
		e.target_id = int(t["id"])
		e.target_cell = t["cell"]
		return
	if t["kind"] == "colonist":
		var c: Colonist = null
		for o in sim.colonists.list:
			if o.id == int(t["id"]):
				c = o
		if c != null and sim.pathfinder.can_approach(e.cell, c.cell):
			e.target_kind = Enemy.Target.COLONIST
			e.target_id = c.id
			e.target_c = c
		return
	var b := sim.buildings.get_by_id(int(t["id"]))
	if b == null or b.destroyed:
		return
	e.target_kind = Enemy.Target.BUILDING
	e.target_id = b.id
	e.target_b = b
	if not sim.pathfinder.can_approach(e.cell, b.nearest_cell_to(e.cell)):
		_sapper_target(e)
# endregion


# region T3
## Hook: a creature next to a belt tile bites it (`structure_dmg` in enemies.json, data/balance
## line_damage.enabled). Own cooldown, so normal attacks are untouched. True if it bit this tick.
## O(5) array reads per enemy; skipped entirely when there are no belts.
func _attack_structure(e: Enemy) -> bool:
	if e.structure_dmg <= 0.0 or e.bite_at > sim.tick or not _hot.line_on or sim.logistics.belts.belt_count == 0:
		return false
	var belts := sim.logistics.belts
	var w := belts.width
	var dir := belts.dir
	var hp := belts.hp
	var ex := e.cell.x
	var ey := e.cell.y
	for off: Vector2i in BeltGrid.BITE_OFFSETS:
		var x := ex + off.x
		var y := ey + off.y
		if x < 0 or y < 0 or x >= w or y >= belts.height:
			continue
		var i := y * w + x
		if dir[i] != 255 and hp[i] > 0.0:
			e.bite_at = sim.tick + e.cd_ticks
			return sim.logistics.damage_belt(Vector2i(x, y), e.structure_dmg * sim.mutation.enemy_damage_mult(e.cell))
	return false


## Turret preference for non-"nearest" modes; `d`/`cur_d` are distances of e / cur to the turret.
func _turret_prefers(mode: String, e: Enemy, cur: Enemy, d: float, cur_d: float) -> bool:
	if mode == "weakest":
		return e.hp < cur.hp or (e.hp == cur.hp and e.id < cur.id)
	# "threatening": the enemy closest to the most valuable building
	var anchor := _threat_anchor()
	var de := Vector2(e.cell).distance_squared_to(anchor)
	var dc := Vector2(cur.cell).distance_squared_to(anchor)
	return de < dc or (de == dc and e.id < cur.id)


func _threat_anchor() -> Vector2:
	var cached: Array = get_meta("t3_anchor", [-1, Vector2.ZERO])  # meta: keeps state dumps unchanged
	if cached[0] != sim.tick:
		var best: Building = null
		for b: Building in sim.buildings.list:
			if b.def.has("turret"):
				continue
			if best == null or int(b.def.get("threat_priority", 0)) > int(best.def.get("threat_priority", 0)):
				best = b
		cached = [sim.tick, best.center() if best != null else Vector2.ZERO]
		set_meta("t3_anchor", cached)
	return cached[1]
# endregion


# region C3 telegraphed attacks
## Deterministic wind-up (no rng): the marked cells are fixed when the wind-up starts, the hit lands
## on whatever stands in them when it ends. Data: enemies.json `telegraph {windup_ticks, shape, size}`.
## State lives in enemy meta "tg" = {left, total, cells} so golden dumps / save stay unchanged.
func _c3_begin(e: Enemy, at: Vector2i) -> bool:
	var tg: Dictionary = e.def.get("telegraph", {})
	if tg.is_empty():
		return false
	var cells: Array[Vector2i] = []
	var size := int(tg.get("radius", 0))
	match String(tg.get("shape", "cell")):
		"line":
			var d := at - e.cell
			var n := maxi(absi(d.x), absi(d.y))
			for i in range(1, maxi(int(tg.get("length", n)), n) + 1):
				cells.append(e.cell + Vector2i(roundi(float(d.x * i) / maxi(n, 1)), roundi(float(d.y * i) / maxi(n, 1))))
		"area":
			for dx in range(-size, size + 1):
				for dy in range(-size, size + 1):
					cells.append(at + Vector2i(dx, dy))
		_:
			cells.append(at)
	var total := maxi(1, int(tg.get("windup_ticks", 1)))
	e.winding = true
	e.set_meta("tg", {"left": total, "total": total, "cells": cells, "mult": float(tg.get("dmg_mult", 1.0))})
	e.clear_path()
	return true


func _c3_wind(e: Enemy) -> void:
	var tg: Dictionary = e.get_meta("tg")
	tg["left"] = int(tg["left"]) - 1
	if int(tg["left"]) > 0:
		return
	e.remove_meta("tg")
	e.winding = false
	e.attack_cd = int(e.def["attack_cooldown_ticks"])
	var cells: Array[Vector2i] = tg["cells"]
	var dmg := float(e.def["damage"]) * float(tg.get("mult", 1.0)) * e.damage_mult * sim.mutation.enemy_damage_mult(e.cell)
	var b := e.target_b
	if e.target_kind == Enemy.Target.BUILDING and b != null and not b.destroyed:
		for c in b.footprint():
			if cells.has(c):
				if not (b.def.get("critical", false) and _scripted("hq_immune")):
					sim.buildings.damage(b, dmg)
				break
	# every colonist still standing in a marked cell is hit once (area / line hit several)
	for col in sim.colonists.list:
		if not col.alive or not cells.has(col.cell) or _scripted("colonist_harmless"):
			continue
		var dodge := sim.perks.mod(col, "dodge_chance")
		if dodge > 0.0 and not e.def.get("ranged", false) and sim.rng.randf() < dodge:
			continue
		sim.health.apply_damage(col, sim.combat.resolve_hit(e.att_stats, sim.combat.def_of(col), dmg, str(e.def.get("dmg_type", "phys"))), "", str(e.def.get("damage_kind", "bite")))  # region E1


## View: [{id, cells, frac}] for enemies winding up (frac 1 = just started, 0 = lands).
func telegraphs() -> Array:
	return _c3_list(false)


## Stable state for hashing: only active wind-ups.
func telegraph_state() -> Array:
	return _c3_list(true)


func _c3_list(full: bool) -> Array:
	var out: Array = []
	for e: Enemy in enemies:
		if e.winding:
			var tg: Dictionary = e.get_meta("tg")
			out.append([e.id, tg["left"]] if full else {"id": e.id, "cells": tg["cells"], "frac": float(tg["left"]) / float(tg["total"])})
	return out
# endregion


# region B2
## Fewer creatures hunt a clean planet (threat.json b2_clean_outpost raid_mult); 1.0 when off.
func _b2_clean_mult() -> float:
	var c: Dictionary = sim.defs.threat.get("b2_clean_outpost", {})
	if bool(c.get("enabled", false)) and sim.contamination.fraction() <= float(c["max_pollution_frac"]):
		return float(c["raid_mult"])
	return 1.0
# endregion


# region SC
## Scent clock + dormancy (balance.json "scent"): refining raises scent, scent shortens the pollution-wave
## countdown (needs preset pacing); a repelled wave puts the nests to sleep (audits still come).
var scent := 0.0
var dormant_until := 0
var _sc_tick := 0


func _sc_init() -> void:
	sim.listen(sim.bus.batch_refined, func(_b: int, _r: String) -> void:
		if _sc_on():
			_sc_decay()
			scent += float(sim.defs.balance["scent"]["per_refine"]))


func _sc_on() -> bool:
	return bool(sim.defs.balance.get("scent", {}).get("enabled", false))


func _sc_decay() -> void:
	var dt := sim.tick - _sc_tick
	_sc_tick = sim.tick
	if dt > 0:
		scent = maxf(0.0, scent - float(sim.defs.balance["scent"]["decay_per_day"]) * float(dt) / float(sim.ticks_per_day))


## Current scent (decayed to now).
func scent_now() -> float:
	if _sc_on():
		_sc_decay()
	return scent


## Pollution countdown multiplier 1/(1+scent/s0); 1.0 when off.
func sc_mult() -> float:
	if not _sc_on():
		return 1.0
	return 1.0 / (1.0 + maxf(0.0, scent_now() - float(sim.defs.balance["scent"].get("free", 0.0))) / float(sim.defs.balance["scent"]["s0"]))


func _sc_dormancy() -> void:
	if not _sc_on():
		return
	var c: Dictionary = sim.defs.balance["scent"]
	var days := lerpf(float(c["dormant_clean_days"]), float(c["dormant_polluted_days"]), clampf(sim.contamination.fraction(), 0.0, 1.0))
	dormant_until = sim.tick + int(days * sim.ticks_per_day)


func dormant_days_left() -> float:
	return maxf(0.0, float(dormant_until - sim.tick) / float(sim.ticks_per_day))


## HUD ticker text ("" when nothing to say).
func scent_ticker() -> String:
	if not _sc_on() or wave_active:
		return ""
	if dormant_days_left() > 0.0:
		return "Nests dormant: %.1f d" % dormant_days_left()
	if awakened and scent_now() >= float(sim.defs.balance["scent"]["high"]):
		return "Scent high: wave in ~%.1f d" % (maxf(0.0, float(next_wave_tick - sim.tick)) / float(sim.ticks_per_day))
	return ""
# endregion


# region RV: the first wave waits for the first refined batch (the pillar, felt), at most N extra days


func _rv_on_first_refine() -> void:
	set_meta("rv_refined", true)  # meta: keeps the golden state dump unchanged
	sim.bus.letter_received.emit("Warden PA", "Shipment 1 departed. The planet has noticed.")


func _rv_gate_ok() -> bool:
	if wave_index > 0 or has_meta("rv_refined"):
		return true
	var extra := float(cfg.get("first_wave_gate_days", 0.0))
	return sim.tick >= next_wave_tick + int(extra * sim.ticks_per_day)
# endregion
