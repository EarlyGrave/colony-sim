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


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.balance["threat"]
	sim.listen(sim.bus.first_refine_done, awaken)
	sim.listen(sim.bus.item_mined, _on_item_mined)


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
	return _attract_mult() * (float(cfg["base_strength"]) \
		+ float(cfg["per_wave"]) * (index - 1) \
		+ float(cfg["per_wealth"]) * colony_wealth() \
		+ float(cfg["per_refined"]) * sim.ledger.get_count("recipe:refined_essence") \
		+ float(cfg["per_contamination"]) * sim.contamination.level)


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
		if float(r["min_points"]) <= points:
			ids.append(id)
			total += float(r["weight"])
	if ids.is_empty():
		return ""
	var roll := sim.rng.randf() * total
	for id in ids:
		roll -= float(sim.defs.raids[id]["weight"])
		if roll < 0.0:
			return id
	return ids[-1]


## Spends `points` on units of the raid type; returns enemy ids in spawn order.
func compose_raid(id: String, points: float) -> Array[String]:
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
		var roll := sim.rng.randf() * total
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
	if awakened and not wave_active and sim.tick >= next_wave_tick:
		start_wave()
	if awakened and not wave_active and not _warned \
			and next_wave_tick - sim.tick < int(cfg["warning_ticks"]) + sim.idle_work.warning_bonus():  # region idle-work
		_warned = true
		sim.bus.wave_incoming.emit(next_spawn_origin, next_wave_tick - sim.tick)
	_tick_turrets()
	for e: Enemy in enemies.duplicate():
		if e.leaving:
			_tick_leaving(e)
		else:
			_tick_enemy(e)
	if wave_active and not pending_drop.is_empty() and sim.tick >= int(pending_drop["tick"]):
		_do_drop()
	if wave_active and (_attackers() == 0 and pending_drop.is_empty() or sim.tick >= wave_end_tick):
		end_wave()
	while not shots.is_empty() and sim.tick - int(shots[0][2]) > 3:
		shots.pop_front()


func start_wave() -> void:
	wave_index += 1
	wave_active = true
	wave_end_tick = sim.tick + int(cfg["wave_duration_ticks"])
	var strength := raid_points(wave_index)
	if wave_index == 1:
		strength = minf(strength, float(cfg["first_wave_max_points"]))  # tutorial swarm
	var origin := next_spawn_origin if next_spawn_origin.x >= 0 else _pick_spawn_origin()
	raid_id = (force_raid_id if force_raid_id != "" else pick_raid_type(strength)) if origin.x >= 0 else ""
	raid_total = 0
	raid_dead = 0
	retreating = false
	pending_drop = {}
	if raid_id != "":
		var r: Dictionary = sim.defs.raids[raid_id]
		var units := compose_raid(raid_id, strength)
		raid_total = units.size()
		if str(r["spawn"]) == "drop" and not sim.buildings.list.is_empty():
			var b: Building = sim.buildings.list[sim.rng.randi_range(0, sim.buildings.list.size() - 1)]
			var ticks := int(r["tremor_ticks"])
			pending_drop = {"tick": sim.tick + ticks, "building": b.id, "cell": b.cell, "units": units}
			sim.bus.raid_tremor.emit(b.cell, ticks, str(r.get("warning_text", "")))
		else:
			for id in units:
				_spawn(id, _spawn_cell_near(origin))
		sim.bus.raid_started.emit(raid_id, strength, raid_total)
	_alarm_before_wave = sim.alarm
	sim.set_alarm(true)
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
		retreating = true
		for e in enemies:
			e.leaving = true
			e.clear_path()
		sim.bus.raid_retreat.emit(raid_id)


func end_wave() -> void:
	wave_active = false
	raid_id = ""
	pending_drop = {}
	for e in enemies:
		e.leaving = true
		e.clear_path()
	next_wave_tick = sim.tick + int(float(cfg["wave_interval_days"]) * sim.ticks_per_day)
	_schedule_origin()
	sim.set_alarm(_alarm_before_wave)
	sim.bus.wave_ended.emit(wave_index)


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


## Compass side of a map cell relative to the map center: "север", "юг", ...
func side_name(c: Vector2i) -> String:
	var d := c - sim.map_center()
	if absi(d.x) >= absi(d.y):
		return "востока" if d.x > 0 else "запада"
	return "юга" if d.y > 0 else "севера"


func _pick_spawn_origin() -> Vector2i:
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
	return e


# --- Enemy behaviour -------------------------------------------------------------

func _tick_enemy(e: Enemy) -> void:
	e.attack_cd = maxi(0, e.attack_cd - 1)
	if sim.tick >= e.retarget_at or not _target_valid(e):
		_choose_target(e)
		e.retarget_at = sim.tick + int(cfg["retarget_ticks"])
	if e.target_kind == Enemy.Target.NONE:
		return
	var range_ := float(e.def["attack_range"])
	if e.target_kind == Enemy.Target.BUILDING:
		var b := sim.buildings.get_by_id(e.target_id)
		if b.distance_to(Vector2(e.cell)) <= range_:
			e.clear_path()
			if e.attack_cd == 0:
				e.attack_cd = int(e.def["attack_cooldown_ticks"])
				sim.buildings.damage(b, float(e.def["damage"]))
		elif _approach_building(e, b) == GridMover.Move.FAILED:
			e.retarget_at = sim.tick + 5
	else:
		var c := sim.colonists.get_by_id(e.target_id)
		if Vector2(c.cell).distance_to(Vector2(e.cell)) <= range_:
			e.clear_path()
			if e.attack_cd == 0:
				e.attack_cd = int(e.def["attack_cooldown_ticks"])
				# region perks: dodge_chance avoids melee hits
				var dodge := sim.perks.mod(c, "dodge_chance")
				if dodge > 0.0 and not e.def.get("ranged", false) and sim.rng.randf() < dodge:
					return
				# endregion
				sim.health.apply_damage(c, float(e.def["damage"]), "", str(e.def.get("damage_kind", "bite")))  # region health
		elif e.move_toward(c.cell, sim) == GridMover.Move.FAILED:
			e.retarget_at = sim.tick + 5


func _tick_leaving(e: Enemy) -> void:
	if e.move_toward(e.spawn_cell, sim) != GridMover.Move.MOVING:
		enemies.erase(e)


func _target_valid(e: Enemy) -> bool:
	match e.target_kind:
		Enemy.Target.BUILDING:
			return sim.buildings.get_by_id(e.target_id) != null
		Enemy.Target.COLONIST:
			var c := sim.colonists.get_by_id(e.target_id)
			return c != null and c.alive and not c.hidden
	return false


func _choose_target(e: Enemy) -> void:
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
		if not sim.pathfinder.can_approach(e.cell, best.nearest_cell_to(e.cell)):
			_sapper_target(e)


func damage_enemy(e: Enemy, amount: float) -> void:
	e.hp -= amount
	if e.hp <= 0.0 and enemies.has(e):
		enemies.erase(e)
		kills += 1
		if wave_active:
			raid_dead += 1
			_check_morale()
		sim.bus.enemy_killed.emit(e.id)


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
		for e in enemies:
			if e.leaving:
				continue
			var d := Vector2(e.cell).distance_to(from)
			if d <= best_d:
				best_d = d
				target = e
		if target == null:
			continue
		b.turret_cooldown = int(t["cooldown_ticks"])
		shots.append([from, target.visual_pos(), sim.tick])
		damage_enemy(target, float(t["damage"]))
		sim.buildings.wear(b, float(b.def.get("wear_per_shot", 0.0)))

# region combat
## Living (not leaving) enemies within `r` cells of `pos`, nearest first.
func enemies_in_range(pos: Vector2, r: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var dists: Array[float] = []
	for e in enemies:
		if e.leaving:
			continue
		var d := Vector2(e.cell).distance_to(pos)
		if d > r:
			continue
		var i := 0
		while i < dists.size() and dists[i] <= d:
			i += 1
		dists.insert(i, d)
		out.insert(i, e)
	return out

# region construction
## Walks toward a building; a solid target (wall) is approached from a free neighbour.
func _approach_building(e: Enemy, b: Building) -> int:
	var goal := b.nearest_cell_to(e.cell)
	if not sim.pathfinder.is_walkable(goal):
		goal = sim.pathfinder.best_adjacent(e.cell, goal)
		if goal.x < 0:
			return GridMover.Move.FAILED
	return e.move_toward(goal, sim)


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
# endregion
