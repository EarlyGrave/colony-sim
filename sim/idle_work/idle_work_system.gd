class_name IdleWorkSystem
extends RefCounted
## State and rules for the always-available low-priority work: scrubbing
## waste, patrolling and combat training (data/idle_work.json).
## Jobs/givers live in sim/jobs; this class owns the shared bookkeeping.

var sim: Simulation
## Player-set patrol route; empty = automatic ring around the base.
var patrol_route: Array[Vector2i] = []
## Contamination removed by scrubbing so far (capped, see can_scrub()).
var scrubbed_total := 0.0
## Extra wave warning lead earned by spotting enemies on patrol.
var spot_bonus_ticks := 0
var last_patrol_tick := -1000000
var _spotted_this_wave := false
## colonist id -> tick before which that colonist starts no new patrol
var _patrol_ready: Dictionary = {}
## colonist id -> [day, xp trained that day]
var _trained: Dictionary = {}
var _cfg: Dictionary
## Own sub-stream (seeded from the sim seed) so scrubbing does not shift sim.rng for other systems.
var _rng := RandomNumberGenerator.new()


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_cfg = sim.defs.idle_work
	_rng.seed = sim.seed_value ^ 0x1D1E
	sim.listen(sim.bus.wave_started, _on_wave_started)
	sim.listen(sim.bus.wave_ended, _on_wave_ended)


func _on_wave_started(_i: int, _s: float) -> void:
	spot_bonus_ticks = 0  # the bonus applied to this wave's warning, spent now
	_spotted_this_wave = false


func _on_wave_ended(_i: int) -> void:
	_spotted_this_wave = false


# --- Cleanup -----------------------------------------------------------------

## Scrubbing may remove at most `max_scrub_fraction` of all contamination ever caused.
func can_scrub() -> bool:
	var gross := sim.contamination.level + scrubbed_total
	return sim.contamination.level > 0.0 and scrubbed_total < float(_cfg["cleanup"]["max_scrub_fraction"]) * gross


## Waste stacks near the base that can be scrubbed, in map iteration order.
func scrub_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var center := sim.map_center()
	var r2 := int(_cfg["cleanup"]["radius"]) * int(_cfg["cleanup"]["radius"])
	for cell: Vector2i in sim.items.stacks:
		if not sim.defs.items[sim.items.item_at(cell)].get("contaminates", false):
			continue
		if cell.distance_squared_to(center) <= r2:
			out.append(cell)
	return out


## Finishes one scrub action by `c` at `cell`: removes waste, lowers contamination
## slightly, and may make the colonist ill (toxic exposure).
func complete_scrub(c: Colonist, cell: Vector2i) -> void:
	var cl: Dictionary = _cfg["cleanup"]
	if not sim.items.stacks.has(cell) or not can_scrub():
		return
	var item := sim.items.item_at(cell)
	var n := sim.items.take_at(cell, int(cl["waste_per_scrub"]))
	if n <= 0:
		return
	sim.ledger.record_consumed(item, n, "scrubbed")
	var amount := minf(float(cl["contamination_per_scrub"]), sim.contamination.level)
	sim.contamination.level -= amount
	scrubbed_total += amount
	sim.mutation.scrub_at(cell)  # region mutation
	sim.bus.waste_scrubbed.emit(c.id, cell, amount)
	if sim.health != null and _rng.randf() < float(cl["illness_chance"]):
		sim.health.add_illness(c, str(cl["illness_id"]), float(cl["illness_severity"]), int(cl["illness_ticks"]))


# --- Patrol ------------------------------------------------------------------

static func parse_route(text: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for part in text.split(";", false):
		var xy := part.split(",")
		if xy.size() == 2:
			out.append(Vector2i(int(xy[0]), int(xy[1])))
	return out


func set_route(points: Array[Vector2i]) -> void:
	patrol_route.clear()
	for p in points:
		if sim.map.in_bounds(p) and sim.map.is_passable(p):
			patrol_route.append(p)
	sim.bus.patrol_route_changed.emit(patrol_route.size())


## The route walked now: the player's, or a ring around the base.
func route() -> Array[Vector2i]:
	if not patrol_route.is_empty():
		return patrol_route
	return auto_route()


func auto_route() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var center := sim.map_center()
	var n := int(_cfg["patrol"]["auto_points"])
	var radius := float(_cfg["patrol"]["auto_radius"])
	for i in n:
		var a := TAU * i / n
		var want := center + Vector2i(roundi(cos(a) * radius), roundi(sin(a) * radius))
		var cell := _nearest_passable(want)
		if cell.x >= 0 and not out.has(cell):
			out.append(cell)
	return out


func _nearest_passable(want: Vector2i) -> Vector2i:
	for r in 6:
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var c := want + Vector2i(x, y)
				if sim.map.in_bounds(c) and sim.map.is_passable(c) and not sim.buildings.occupied(c):
					return c
	return Vector2i(-1, -1)


func patrol_ready(c: Colonist) -> bool:
	return sim.tick >= int(_patrol_ready.get(c.id, 0))


func patrol_finished(c: Colonist) -> void:
	_patrol_ready[c.id] = sim.tick + int(_cfg["patrol"]["cooldown_ticks"])


## Called by PatrolJob while walking: remembers the vigil and looks for enemies.
func patrol_scan(c: Colonist) -> void:
	last_patrol_tick = sim.tick
	var found := sim.threats.enemies_in_range(Vector2(c.cell), float(_cfg["patrol"]["detect_radius"]))
	if found.is_empty() or _spotted_this_wave:
		return
	_spotted_this_wave = true
	spot_bonus_ticks = mini(spot_bonus_ticks + int(_cfg["patrol"]["spot_bonus_ticks"]), int(_cfg["patrol"]["max_spot_bonus_ticks"]))
	sim.bus.patrol_spotted.emit(c.id, found[0].cell, found.size())


## Extra lead time (ticks) added to the wave warning: a fresh patrol keeps watch,
## and enemies spotted on patrol extend it further.
func warning_bonus() -> int:
	var b := spot_bonus_ticks
	if sim.tick - last_patrol_tick <= int(_cfg["patrol"]["vigil_window_ticks"]):
		b += int(_cfg["patrol"]["vigil_bonus_ticks"])
	return b


# --- Training ----------------------------------------------------------------

## Combat skill with the lowest level (ties: data order), or "" if all are maxed.
func training_skill(c: Colonist) -> String:
	var best := ""
	var best_level := 1 << 30
	for s: String in _cfg["training"]["skills"]:
		var l := c.skills.level(s)
		if l < best_level and l < int(sim.defs.skills["max_level"]):
			best = s
			best_level = l
	return best


func training_left(c: Colonist) -> float:
	var rec: Array = _trained.get(c.id, [-1, 0.0])
	if int(rec[0]) != sim.day():
		return float(_cfg["training"]["daily_xp_cap"])
	return maxf(0.0, float(_cfg["training"]["daily_xp_cap"]) - float(rec[1]))


## One tick of training: grants xp (counted against the daily cap).
func train_tick(c: Colonist, skill: String) -> void:
	var xp := minf(float(_cfg["training"]["xp_per_tick"]), training_left(c))
	if xp <= 0.0:
		return
	var rec: Array = _trained.get(c.id, [-1, 0.0])
	if int(rec[0]) != sim.day():
		rec = [sim.day(), 0.0]
	rec[1] = float(rec[1]) + xp
	_trained[c.id] = rec
	if c.skills.add_xp(sim.defs, skill, xp):
		sim.bus.skill_leveled.emit(c.id, skill, c.skills.level(skill))
