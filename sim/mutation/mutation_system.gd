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
# region P2
## Time-sliced update state (only used when the map is bigger than one slice of
## `field_perf.slice_cells`; small maps keep the exact one-shot update).
var slices := 1
var _cycle_on := false
var _sum := 0.0
var _scale := 1.0
var _act_cur := PackedByteArray()  ## rows of `field` that may hold non-zero values
var _act_next := PackedByteArray()  ## same for rows already written into `_scratch`
var _act_scr := PackedByteArray()  ## rows of `_scratch` that hold stale non-zero data
var _rows_done := 0
var _zero_eps := 0.00001
## Per-row flag: row changed since the view last consumed it.
var dirty_rows := PackedByteArray()
var diffuse_calls := 0
# endregion


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_cfg = sim.defs.mutation
	_rng.seed = sim.seed_value ^ 0x3A7B
	field.resize(sim.map.width * sim.map.height)
	_scratch.resize(field.size())
	sim.listen(sim.bus.batch_refined, _on_batch_refined)
	_init_slicing()  # region P2


func _on_batch_refined(building_id: int, _recipe: String) -> void:
	var b := sim.buildings.get_by_id(building_id)
	if b != null:
		_pending_batches.append(b.cell)


func tainted_threshold() -> float:
	return float(_cfg["tainted"])


func mutated_threshold() -> float:
	return float(_cfg["mutated"])


# region P2
func _init_slicing() -> void:
	var fp: Dictionary = sim.defs.balance["field_perf"]
	_zero_eps = float(fp["zero_eps"])
	var n := int(_cfg["update_ticks"])
	dirty_rows.resize(sim.map.height)
	dirty_rows.fill(1)
	slices = clampi(ceili(float(field.size()) / float(fp["slice_cells"])), 1, mini(n, sim.map.height))
	if slices > 1:
		_act_cur.resize(sim.map.height)
		_act_next.resize(sim.map.height)
		_act_scr.resize(sim.map.height)


## Marks a field row as possibly non-zero and as dirty for the overlay.
func _touch(y: int) -> void:
	if slices > 1:
		_act_cur[y] = 1
		_act_next[y] = 1
	dirty_rows[y] = 1


## Applies a delta to one cell (and to the half-built next field if its row is done).
func _bump(i: int, delta: float, cap: float) -> void:
	var y := i / sim.map.width
	field[i] = clampf(field[i] + delta, 0.0, cap)
	if slices > 1 and _cycle_on and y < _rows_done:
		_scratch[i] = clampf(_scratch[i] + delta, 0.0, cap)
	_touch(y)
# endregion


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
		_bump(_idx(c), amount, float(_cfg["cap"]))  # region P2


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
			_bump(_idx(p), -cut, INF)  # region P2
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
	if slices > 1:  # region P2
		_tick_sliced(n)
		return
	if sim.tick % n != 0:
		return
	_add_sources()
	_diffuse()
	_normalize()
	dirty_rows.fill(1)  # region P2
	_detect_mutations()
	_grow_blooms()
	_expose_colonists(n)


# region P2
func _tick_sliced(n: int) -> void:
	var p := sim.tick % n
	if p >= slices:
		return
	var h := sim.map.height
	if p == 0:
		_cycle_on = true
		_rows_done = 0
		_sum = 0.0
		_add_sources()
		_grow_blooms()
		_expose_colonists(n)
	if not _cycle_on:
		return
	var y1 := h * (p + 1) / slices
	_diffuse_rows(_rows_done, y1)
	_rows_done = y1
	if p == slices - 1:
		_finish_cycle()


func _diffuse_rows(y0: int, y1: int) -> void:
	diffuse_calls += 1
	var w := sim.map.width
	var h := sim.map.height
	var k := float(_cfg["diffusion"])
	var mult := (1.0 - float(_cfg["decay_per_update"])) * _scale
	var cap := float(_cfg["cap"])
	var th := mutated_threshold()
	var eps := _zero_eps
	var sum := 0.0
	for y in range(y0, y1):
		if _act_cur[y] == 0 and (y == 0 or _act_cur[y - 1] == 0) and (y == h - 1 or _act_cur[y + 1] == 0):
			if _act_scr[y] != 0:
				var b := y * w
				for x in w:
					_scratch[b + x] = 0.0
				_touch_dirty(y)
			continue
		var any := false
		var changed := false
		for x in w:
			var i := y * w + x
			var v := field[i]
			var s := 0.0
			var cnt := 0
			if x > 0:
				s += field[i - 1]
				cnt += 1
			if x < w - 1:
				s += field[i + 1]
				cnt += 1
			if y > 0:
				s += field[i - w]
				cnt += 1
			if y < h - 1:
				s += field[i + w]
				cnt += 1
			var nv := (v + k * (s / cnt - v)) * mult
			if nv < eps:
				nv = 0.0
			elif nv > cap:
				nv = cap
			if nv != 0.0:
				any = true
				sum += nv
			if nv != v:
				changed = true
			_scratch[i] = nv
			var c := Vector2i(x, y)
			if nv >= th:
				if not _mutated.has(c):
					_mutated[c] = true
					sim.bus.cell_mutated.emit(c)
			elif _mutated.has(c):
				_mutated.erase(c)
		if any:
			_act_next[y] = 1
		if changed:
			_touch_dirty(y)
	_sum += sum


func _touch_dirty(y: int) -> void:
	dirty_rows[y] = 1


func _finish_cycle() -> void:
	var tmp := field
	field = _scratch
	_scratch = tmp
	var ta := _act_scr
	_act_scr = _act_cur
	_act_cur = _act_next
	_act_next = ta
	_act_next.fill(0)
	# Normalisation is linear, so its scale is applied inside the next cycle's diffusion.
	var m := _sum / field.size()
	_scale = 1.0
	var target := sim.contamination.fraction() * float(_cfg["mean_at_max"])
	if m > 0.00001:
		var clampv := float(_cfg["normalize_clamp"])
		var s := clampf(target / m, 1.0 - clampv, 1.0 + clampv)
		if absf(s - 1.0) >= 0.0001:
			_scale = s
	_cycle_on = false
# endregion


func _add_sources() -> void:
	var per_waste := float(_cfg["source_per_waste"])
	var cap := float(_cfg["cap"])
	for c: Vector2i in sim.items.stacks:
		var st: Dictionary = sim.items.stacks[c]
		if not sim.defs.items[st["item"]].get("contaminates", false):
			continue
		var zone := sim.map.get_zone(c)
		var f := float(sim.defs.zones[zone]["waste_emission_factor"]) if zone != "" else 1.0
		_bump(_idx(c), f * int(st["count"]) * per_waste, cap)  # region P2
	for c in _pending_batches:
		_bump(_idx(c), float(_cfg["source_per_batch"]), cap)  # region P2
	_pending_batches.clear()


func _diffuse() -> void:
	var w := sim.map.width
	var h := sim.map.height
	var k := float(_cfg["diffusion"])
	var decay := 1.0 - float(_cfg["decay_per_update"])
	var f := field
	var sc := _scratch
	for y in h:
		var interior_row := y > 0 and y < h - 1
		for x in w:
			var i := y * w + x
			var v := f[i]
			var sum := 0.0
			var cnt := 0
			if interior_row and x > 0 and x < w - 1:
				sum = f[i - 1] + f[i + 1] + f[i - w] + f[i + w]  # same order as below
				cnt = 4
			else:
				if x > 0:
					sum += f[i - 1]
					cnt += 1
				if x < w - 1:
					sum += f[i + 1]
					cnt += 1
				if y > 0:
					sum += f[i - w]
					cnt += 1
				if y < h - 1:
					sum += f[i + w]
					cnt += 1
			sc[i] = (v + k * (sum / cnt - v)) * decay
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
	var any_mutated := not _mutated.is_empty()
	for i in field.size():
		if field[i] >= th:
			var c := Vector2i(i % w, i / w)
			if not _mutated.has(c):
				_mutated[c] = true
				any_mutated = true
				sim.bus.cell_mutated.emit(c)
		elif any_mutated:
			var c := Vector2i(i % w, i / w)
			if _mutated.erase(c):
				any_mutated = not _mutated.is_empty()


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
		if not col.alive or sim.passives.rule(col, "taint_immune"):  # F11W3
			continue
		if not is_tainted(col.cell):
			_exposure[col.id] = 0
			continue
		_exposure[col.id] = int(_exposure.get(col.id, 0)) + n
		if int(_exposure[col.id]) >= int(_cfg["exposure_ticks"]):
			_exposure[col.id] = 0
			if _rng.randf() < float(_cfg["illness_chance"]) * sim.traits.mutation_mult(col) * maxf(0.0, 1.0 + sim.passives.mod(col, "mutation_risk")):  # region traits + F11W3
				sim.health.add_illness(col, str(_cfg["illness_id"]), float(_cfg["illness_severity"]), int(_cfg["illness_ticks"]))
