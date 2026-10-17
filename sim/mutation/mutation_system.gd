class_name MutationSystem
extends RefCounted
## Spatial expression of contamination: a per-cell field fed by waste stacks and
## refinery batches, spread by deterministic diffusion every `update_ticks`.
## Global `sim.contamination.level` stays authoritative: after each update the
## field mean is nudged (by at most `normalize_clamp` per update) toward
## fraction * mean_at_max, so hot spots exist but the average tracks the global level.
## Tainted cells hurt crops and sicken colonists; mutated cells grow blooms
## and empower creatures. data/mutation.json.

var sim: Simulation
## Row-major (y * width + x) cell values.
var field := PackedFloat32Array()
var _cfg: Dictionary
var _rng := RandomNumberGenerator.new()
var _scratch := PackedFloat32Array()
## Cells that already crossed the mutated threshold (insertion-ordered).
var _mutated: Dictionary = {}
var _blooms: Dictionary = {}
## colonist id -> ticks spent standing on tainted ground
var _exposure: Dictionary = {}
var _pending_batches: Array[Vector2i] = []


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_cfg = sim.defs.mutation
	_rng.seed = sim.seed_value ^ 0x3A7B
	field.resize(sim.map.width * sim.map.height)
	_scratch.resize(field.size())
	sim.listen(sim.bus.batch_refined, _on_batch_refined)


func _on_batch_refined(building_id: int, _recipe: String) -> void:
	var b := sim.buildings.get_by_id(building_id)
	if b != null:
		_pending_batches.append(b.cell)


func tainted_threshold() -> float:
	return float(_cfg["tainted"])


func mutated_threshold() -> float:
	return float(_cfg["mutated"])


func _idx(c: Vector2i) -> int:
	return c.y * sim.map.width + c.x


func value_at(c: Vector2i) -> float:
	return field[_idx(c)] if sim.map.in_bounds(c) else 0.0


func is_tainted(c: Vector2i) -> bool:
	return value_at(c) >= tainted_threshold()


func is_mutated(c: Vector2i) -> bool:
	return value_at(c) >= mutated_threshold()


func mean() -> float:
	if field.is_empty():
		return 0.0
	var s := 0.0
	for v in field:
		s += v
	return s / field.size()


## Test/tool helper: adds `amount` to one cell (clamped to the cap).
func add_at(c: Vector2i, amount: float) -> void:
	if sim.map.in_bounds(c):
		field[_idx(c)] = clampf(field[_idx(c)] + amount, 0.0, float(_cfg["cap"]))


# --- Gameplay hooks ---------------------------------------------------------------

## 1.0 on clean soil, down to crop_growth_min at the mutated threshold.
func growth_mult(c: Vector2i) -> float:
	return _soil_mult(c, float(_cfg["crop_growth_min"]))


func yield_mult(c: Vector2i) -> float:
	return _soil_mult(c, float(_cfg["crop_yield_min"]))


func _soil_mult(c: Vector2i, floor_mult: float) -> float:
	var v := value_at(c)
	if v < tainted_threshold():
		return 1.0
	var t := clampf((v - tainted_threshold()) / maxf(mutated_threshold() - tainted_threshold(), 0.001), 0.0, 1.0)
	return lerpf(1.0, floor_mult, t)


func enemy_damage_mult(c: Vector2i) -> float:
	return 1.0 + float(_cfg["enemy_damage_bonus"]) if is_mutated(c) else 1.0


# --- Commands / cleanup --------------------------------------------------------------

## Spends refined essence to lower the field around `c`. Returns false if it can't.
func purify(c: Vector2i) -> bool:
	if not sim.map.in_bounds(c) or value_at(c) <= 0.0:
		return false
	if not sim.items.consume_stored(str(_cfg["purify_item"]), int(_cfg["purify_cost"]), c):
		return false
	sim.ledger.record_consumed(str(_cfg["purify_item"]), int(_cfg["purify_cost"]), "purify")
	_reduce_around(c, float(_cfg["purify_amount"]), int(_cfg["purify_radius"]))
	sim.bus.cell_purified.emit(c)
	return true


## Scrubbing waste also cleans the ground it lay on.
func scrub_at(c: Vector2i) -> void:
	_reduce_around(c, float(_cfg["scrub_cell_amount"]), 1)


func _reduce_around(c: Vector2i, amount: float, radius: int) -> void:
	var removed := 0.0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var p := c + Vector2i(dx, dy)
			if not sim.map.in_bounds(p):
				continue
			var cut := minf(field[_idx(p)], amount if p == c else amount * 0.5)
			field[_idx(p)] -= cut
			removed += cut
			if field[_idx(p)] < mutated_threshold():
				_mutated.erase(p)
	# Keep the global level consistent with the cleaned mass.
	var max_level := float(sim.defs.balance["contamination"]["max"])
	var per_cell_to_level := max_level / (float(_cfg["mean_at_max"]) * field.size())
	sim.contamination.level = maxf(0.0, sim.contamination.level - removed * per_cell_to_level)


# --- Tick -----------------------------------------------------------------------------

func tick() -> void:
	var n := int(_cfg["update_ticks"])
	if sim.tick % n != 0:
		return
	_add_sources()
	_diffuse()
	_normalize()
	_detect_mutations()
	_grow_blooms()
	_expose_colonists(n)


func _add_sources() -> void:
	var per_waste := float(_cfg["source_per_waste"])
	var cap := float(_cfg["cap"])
	for c: Vector2i in sim.items.stacks:
		var st: Dictionary = sim.items.stacks[c]
		if not sim.defs.items[st["item"]].get("contaminates", false):
			continue
		var zone := sim.map.get_zone(c)
		var f := float(sim.defs.zones[zone]["waste_emission_factor"]) if zone != "" else 1.0
		field[_idx(c)] = minf(cap, field[_idx(c)] + f * int(st["count"]) * per_waste)
	for c in _pending_batches:
		field[_idx(c)] = minf(cap, field[_idx(c)] + float(_cfg["source_per_batch"]))
	_pending_batches.clear()


func _diffuse() -> void:
	var w := sim.map.width
	var h := sim.map.height
	var k := float(_cfg["diffusion"])
	var decay := 1.0 - float(_cfg["decay_per_update"])
	for y in h:
		for x in w:
			var i := y * w + x
			var v := field[i]
			var sum := 0.0
			var cnt := 0
			if x > 0:
				sum += field[i - 1]
				cnt += 1
			if x < w - 1:
				sum += field[i + 1]
				cnt += 1
			if y > 0:
				sum += field[i - w]
				cnt += 1
			if y < h - 1:
				sum += field[i + w]
				cnt += 1
			_scratch[i] = (v + k * (sum / cnt - v)) * decay
	var tmp := field
	field = _scratch
	_scratch = tmp


func _normalize() -> void:
	var m := mean()
	var target := sim.contamination.fraction() * float(_cfg["mean_at_max"])
	if m <= 0.00001:
		return
	var clampv := float(_cfg["normalize_clamp"])
	var s := clampf(target / m, 1.0 - clampv, 1.0 + clampv)
	if absf(s - 1.0) < 0.0001:
		return
	var cap := float(_cfg["cap"])
	for i in field.size():
		field[i] = minf(cap, field[i] * s)


func _detect_mutations() -> void:
	var th := mutated_threshold()
	var w := sim.map.width
	for i in field.size():
		var c := Vector2i(i % w, i / w)
		if field[i] >= th:
			if not _mutated.has(c):
				_mutated[c] = true
				sim.bus.cell_mutated.emit(c)
		elif _mutated.has(c):
			_mutated.erase(c)


func _grow_blooms() -> void:
	var item := str(_cfg["bloom_item"])
	for c: Vector2i in _blooms.keys():
		if sim.items.item_at(c) != item:
			_blooms.erase(c)  # harvested or moved
	if _mutated.is_empty() or _blooms.size() >= int(_cfg["bloom_max"]):
		return
	for c: Vector2i in _mutated:
		if _rng.randf() >= float(_cfg["bloom_chance"]):
			continue
		if sim.items.stacks.has(c) or not sim.cell_free_for_items(c) or sim.map.get_zone(c) != "":
			continue
		sim.ledger.record_produced(item, 1, "mutation")
		sim.items.add_at(c, item, 1)
		_blooms[c] = true
		if _blooms.size() >= int(_cfg["bloom_max"]):
			return


func _expose_colonists(n: int) -> void:
	if sim.health == null:
		return
	for col in sim.colonists.list:
		if not col.alive:
			continue
		if not is_tainted(col.cell):
			_exposure[col.id] = 0
			continue
		_exposure[col.id] = int(_exposure.get(col.id, 0)) + n
		if int(_exposure[col.id]) >= int(_cfg["exposure_ticks"]):
			_exposure[col.id] = 0
			if _rng.randf() < float(_cfg["illness_chance"]):
				sim.health.add_illness(col, str(_cfg["illness_id"]), float(_cfg["illness_severity"]), int(_cfg["illness_ticks"]))
