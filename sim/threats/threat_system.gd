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


## Threat budget of a wave: the colony's growth is what calls the creatures.
func wave_strength(index: int) -> float:
	return float(cfg["base_strength"]) \
		+ float(cfg["per_wave"]) * (index - 1) \
		+ float(cfg["per_refined"]) * sim.ledger.get_count("recipe:refined_essence") \
		+ float(cfg["per_contamination"]) * sim.contamination.level


func tick() -> void:
	if awakened and not wave_active and sim.tick >= next_wave_tick:
		start_wave()
	if awakened and not wave_active and not _warned \
			and next_wave_tick - sim.tick < int(cfg["warning_ticks"]):
		_warned = true
		sim.bus.wave_incoming.emit(next_spawn_origin, next_wave_tick - sim.tick)
	_tick_turrets()
	for e: Enemy in enemies.duplicate():
		if e.leaving:
			_tick_leaving(e)
		else:
			_tick_enemy(e)
	if wave_active and (_attackers() == 0 or sim.tick >= wave_end_tick):
		end_wave()
	while not shots.is_empty() and sim.tick - int(shots[0][2]) > 3:
		shots.pop_front()


func start_wave() -> void:
	wave_index += 1
	wave_active = true
	wave_end_tick = sim.tick + int(cfg["wave_duration_ticks"])
	var strength := wave_strength(wave_index)
	var origin := next_spawn_origin if next_spawn_origin.x >= 0 else _pick_spawn_origin()
	var budget := strength if origin.x >= 0 else 0.0
	var guard := 200
	while guard > 0:
		guard -= 1
		var options: Array[String] = []
		for id: String in sim.defs.enemies:
			var d: Dictionary = sim.defs.enemies[id]
			if float(d["threat_cost"]) <= budget and int(d.get("min_wave", 1)) <= wave_index:
				options.append(id)
		if options.is_empty():
			break
		var pick := options[sim.rng.randi_range(0, options.size() - 1)]
		budget -= float(sim.defs.enemies[pick]["threat_cost"])
		_spawn(pick, _spawn_cell_near(origin))
	_alarm_before_wave = sim.alarm
	sim.set_alarm(true)
	sim.bus.wave_started.emit(wave_index, strength)


func end_wave() -> void:
	wave_active = false
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
		if sim.pathfinder.reachable(c, home):
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
		if sim.pathfinder.reachable(c, origin):
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
		elif e.move_toward(b.nearest_cell_to(e.cell), sim) == GridMover.Move.FAILED:
			e.retarget_at = sim.tick + 5
	else:
		var c := sim.colonists.get_by_id(e.target_id)
		if Vector2(c.cell).distance_to(Vector2(e.cell)) <= range_:
			e.clear_path()
			if e.attack_cd == 0:
				e.attack_cd = int(e.def["attack_cooldown_ticks"])
				c.hp -= float(e.def["damage"])
				if c.hp <= 0.0:
					sim.colonists.kill(c)
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
			if d <= best_d:
				best_d = d
				e.target_kind = Enemy.Target.COLONIST
				e.target_id = c.id
	if e.target_kind != Enemy.Target.NONE:
		return
	# 2) A turret shooting at us; 3) the most valuable building.
	var best: Building = null
	var best_score := -INF
	for b in sim.buildings.list:
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


func damage_enemy(e: Enemy, amount: float) -> void:
	e.hp -= amount
	if e.hp <= 0.0 and enemies.has(e):
		enemies.erase(e)
		kills += 1
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
