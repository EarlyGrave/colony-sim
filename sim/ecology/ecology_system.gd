class_name EcologySystem
extends RefCounted
## Creature nests on the map edge with a pollution-fed "hunger" bank (T5).
##
## Each nest absorbs local + planet-wide pollution into its bank. A raid may field
## `starved_max` units for free; every unit beyond that is paid from the banks
## (`unit_cost`), so a clean planet only ever sends weak waves. Waves spawn at the
## fullest nest. Mutant variants (enemies.json "variants") are rolled per unit from
## the nest's pollution band, with hysteresis on the way down. Data: data/ecology.json.
## Own RNG stream (seed ^ 0xEC01); never touches sim.rng or wave_rng.

var sim: Simulation
var cfg: Dictionary
## Per nest: {cell: Vector2i, bank: float, tier: int}
var nests: Array[Dictionary] = []
var rally_sent := false
var _rally_for := -1
var _rng := RandomNumberGenerator.new()
## Last wave summary (tests / HUD): {free, paid, dropped, spent}
var last_muster: Dictionary = {}
var total_gain := 0.0
var total_units := 0
## Nest the current wave leaves from (-1 = none).
var wave_nest := -1


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.ecology
	_rng.seed = sim.seed_value ^ 0xEC01


func active() -> bool:
	return bool(cfg.get("enabled", true)) and not nests.is_empty()


## Places 2-4 nests on reachable map-edge cells, spread apart. Deterministic per seed.
func generate() -> void:
	nests.clear()
	if not bool(cfg.get("enabled", true)):
		return
	var want := _rng.randi_range(int(cfg["nests_min"]), int(cfg["nests_max"]))
	var w := sim.map.width
	var h := sim.map.height
	var margin := int(cfg["edge_margin"])
	var min_d := float(cfg["min_nest_distance"])
	var home := sim.map_center()
	for attempt in 400:
		if nests.size() >= want:
			break
		var side := _rng.randi_range(0, 3)
		var t := _rng.randi_range(margin, (w if side < 2 else h) - 1 - margin)
		var c: Vector2i
		match side:
			0: c = Vector2i(t, margin)
			1: c = Vector2i(t, h - 1 - margin)
			2: c = Vector2i(margin, t)
			_: c = Vector2i(w - 1 - margin, t)
		var ok := sim.pathfinder.reachable_terrain(c, home)
		for n in nests:
			if Vector2(n["cell"]).distance_to(Vector2(c)) < min_d:
				ok = false
		if ok:
			nests.append({"cell": c, "bank": float(cfg["start_bank"]), "tier": 0})


## Pollution felt by a nest: mean of the local field around it + planet-wide level.
func pollution_at(c: Vector2i) -> float:
	var r := int(cfg["sample_radius"])
	var s := 0.0
	for d: Vector2i in [Vector2i.ZERO, Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
		s += sim.mutation.value_at(c + d)
	var global := sim.contamination.fraction() * float(sim.defs.mutation["mean_at_max"])
	return s / 5.0 + float(cfg["global_mix"]) * global


## Pressure multiplier from AI-chip benches (T4 stub: 0 chips until it merges).
func chip_pressure() -> float:
	var n := 0
	if sim.get("chips") != null and sim.chips.has_method("active_count"):
		n = int(sim.chips.active_count())
	return minf(float(cfg["chip_pressure_cap"]), pow(float(cfg["chip_pressure"]), n))


func tick() -> void:
	if nests.is_empty() or sim.tick % int(cfg["update_ticks"]) != 0:
		return
	var dt := float(cfg["update_ticks"]) / float(sim.ticks_per_day)
	var press := chip_pressure()
	for n in nests:
		var p := pollution_at(n["cell"])
		var gain := p * float(cfg["absorb_rate"]) * dt * press
		var before: float = n["bank"]
		n["bank"] = minf(float(cfg["bank_cap"]), before + gain)
		total_gain += n["bank"] - before
		n["tier"] = tier_for(p, int(n["tier"]))
	_tick_rally()


## Band 0..N for pollution `p`; falling out of a band needs p < min * revert_ratio.
func tier_for(p: float, current: int) -> int:
	var bands: Array = cfg["variant_bands"]
	var t := 0
	for i in bands.size():
		var m := float(bands[i]["min"])
		if p >= m or (i < current and p >= m * float(cfg["revert_ratio"])):
			t = i + 1
	return t


func variant_chance(tier: int) -> float:
	return 0.0 if tier <= 0 else float(cfg["variant_bands"][tier - 1]["chance"])


func bank_total() -> float:
	var s := 0.0
	for n in nests:
		s += n["bank"]
	return s


## The nest the next wave comes from: fullest bank, ties by index.
func lead_nest() -> int:
	var best := -1
	for i in nests.size():
		if best < 0 or float(nests[i]["bank"]) > float(nests[best]["bank"]):
			best = i
	return best


func lead_cell() -> Vector2i:
	var i := lead_nest()
	return nests[i]["cell"] if i >= 0 else Vector2i(-1, -1)


func unit_cost(enemy_id: String) -> float:
	return float(cfg["unit_cost"].get(enemy_id, cfg["default_unit_cost"]))


## Caps a composed raid to what the nests can feed; spends the banks. Returns the kept units.
func muster(units: Array[String]) -> Array[String]:
	last_muster = {"free": 0, "paid": 0, "dropped": 0, "spent": 0.0}
	if not active():
		return units
	var kept: Array[String] = []
	var free := int(cfg["starved_max"])
	var avail := bank_total()
	var spent := 0.0
	for id in units:
		if kept.size() < free:
			kept.append(id)
			last_muster["free"] += 1
			continue
		var cost := unit_cost(id)
		if spent + cost <= avail:
			spent += cost
			kept.append(id)
			last_muster["paid"] += 1
		else:
			last_muster["dropped"] += 1
	_spend(spent)
	last_muster["spent"] = spent
	total_units += kept.size()
	return kept


func _spend(amount: float) -> void:
	var left := amount
	while left > 0.0001:
		var i := lead_nest()
		if i < 0 or float(nests[i]["bank"]) <= 0.0:
			break
		var take := minf(left, float(nests[i]["bank"]))
		nests[i]["bank"] = float(nests[i]["bank"]) - take
		left -= take


## Rolls the mutant variant for a unit born at nest `nest_idx` (own RNG stream).
## Returns the variant id for enemy `def` or "".
func roll_variant(def: Dictionary, nest_idx: int) -> String:
	var vs: Dictionary = def.get("variants", {})
	if vs.is_empty() or nest_idx < 0:
		return ""
	var ch := variant_chance(int(nests[nest_idx]["tier"]))
	if _rng.randf() < ch:
		return str(vs.keys()[0])
	return ""


## Index of the nest nearest to cell `c`, or -1.
func nest_at(c: Vector2i) -> int:
	var best := -1
	var bd := INF
	for i in nests.size():
		var d := Vector2(nests[i]["cell"]).distance_squared_to(Vector2(c))
		if d < bd:
			bd = d
			best = i
	return best


# --- Rally warning -------------------------------------------------------------

func _tick_rally() -> void:
	var t := sim.threats
	if not t.awakened or t.wave_active:
		return
	if _rally_for != t.next_wave_tick:
		_rally_for = t.next_wave_tick
		rally_sent = false
	if rally_sent or sim.tick < t.next_wave_tick - int(cfg["rally_ticks"]):
		return
	rally_sent = true
	var side := t.side_name(lead_cell())
	sim.bus.letter_received.emit("Creatures are massing",
		"Something is gathering in the %s. A raid will leave the nest soon - prepare the defences." % side)


## Ticks until the next wave while a rally is on, else -1 (HUD strip).
func rally_ticks_left() -> int:
	if not rally_sent or sim.threats.wave_active:
		return -1
	return maxi(0, sim.threats.next_wave_tick - sim.tick)


func state_parts() -> Array:
	var out: Array = [rally_sent, total_units]
	for n in nests:
		out.append([n["cell"], snappedf(n["bank"], 0.0001), n["tier"]])
	return out
