class_name ThreatModel
extends RefCounted
## Attention ("aggro") model, data/threat.json. Every building and colonist has a threat
## value; creatures pick the target with the best  (value + pollution*k_poll) / (1 + (dist/d0)^2),
## sticky to the current target, with a per-region cap on summed building threat.

var sim: Simulation
var cfg: Dictionary
## Cached candidates: parallel arrays, buildings first (list order) then colonists.
var _kind: Array[int] = []  # 0 building, 1 colonist
var _id: Array[int] = []
var _ref: Array = []
var _val: Array[float] = []
var _type: Array[String] = []
var _cache_tick := -1000000
# region W1a
var _geo := PackedInt32Array()  # 4 ints per candidate: building x, y, size.x, size.y (unused for others)
var _bias_cache: Dictionary = {}  # enemy def_id -> PackedFloat64Array (species bias per candidate), reset in refresh
var _index: Dictionary = {}  # (kind << 32 | id) -> candidate index
var _belt_lo := 0  # belt candidates occupy [_belt_lo, _belt_hi) in index order (= region-key order)
var _belt_hi := 0
var _belt_rx: Array[int] = []  # per belt candidate: region x / y
var _belt_ry: Array[int] = []
var _belt_grid := PackedInt32Array()  # region grid -> candidate index, -1 if none
var _bgw := 0
var _bgh := 0
var _belt_max := 0.0
var _belts_grid_ref: BeltGrid
var _cand_di := PackedInt32Array()  # per belt candidate: dir-array index of its cell
var _memo: Dictionary = {}
var _memo_sig := -1
var _g_x := PackedInt32Array()  # per region cell: candidate cell x / y / dir index / value (valid when _belt_grid >= 0)
var _g_y := PackedInt32Array()
var _g_di := PackedInt32Array()
var _g_val := PackedFloat64Array()
## sqrt(n) rounded to float32 = what Vector2.distance_to returns for integer deltas with dx^2+dy^2 == n (lazy, grows on demand).
var _dist_tab := PackedFloat32Array()
var _bdir := PackedByteArray()
var _bw := 0
# endregion
# region R3X
var _belt_tick := -1000000
var _d0 := 1.0
var _flags_live := false  # region W2d: any ability flag live (read per pick)
var _line_on := true  # region W2d: balance line_damage.enabled, read once per pick
var _gen := 0  # region W2d: pick memo generation (candidate epoch / belt set change)
var _gen_cache := -1
var _cand_gen := 0
var _p_kind: Array[int] = []
var _p_id: Array[int] = []
var _p_val: Array[float] = []
var _p_geo := PackedInt32Array()
var _p_ref: Array = []
var _gen_ver := -1
## Belt candidates per region: [region_key, cell, count], rebuilt every `belt_recompute_ticks`.
var _belts: Array = []
# endregion


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.threat


## Threat of a building from its state (no pollution, no regional cap).
func building_value(b: Building) -> float:
	var base: float
	if b.def.has("threat"):
		base = float(b.def["threat"])
	elif cfg["base"].has(b.def_id):
		base = float(cfg["base"][b.def_id])
	else:
		base = float(b.def.get("threat_priority", 0)) * float(cfg["per_priority"]) + float(cfg["base"]["default"])
	if base <= 0.0:
		return 0.0
	if Decoy.is_decoy(b):  # region R3X: lit/unlit/burst handled by the decoy itself
		return Decoy.threat_now(b)
	var mods: Dictionary = cfg["state_mod"]
	var own: Dictionary = b.def.get("threat_mods", {})
	var v := base
	if b.broken:
		v *= _mod("broken", own, mods)
	elif b.progress > 0 or b.mach_acc > 0.0:
		v *= _mod("working", own, mods)
	elif b.is_machine():
		v *= _mod("idle", own, mods)
	if b.def.has("turret") and b.turret_cooldown > 0:
		v *= _mod("firing", own, mods)
	if b.output.has("refined_essence") or b.input.has("refined_essence"):
		v *= _mod("carrying_essence", own, mods)
	if sim.chips != null and sim.chips.threat_mult(b) > 1.0:  # region R3X: a chip works here
		v *= _mod("chip", own, mods)
	for f: String in b.threat_flags:  # insertion order is deterministic (set by sim code)
		if b.threat_flags[f]:
			v *= _mod(f, own, mods)
	return v


func _mod(k: String, own: Dictionary, mods: Dictionary) -> float:
	return float(own.get(k, mods.get(k, 1.0)))


func colonist_value(c: Colonist) -> float:
	var v := float(cfg["base"]["colonist"])
	var m: Dictionary = cfg["colonist_mod"]
	if c.combat != null:
		if c.combat.drafted:
			v *= float(m["drafted"])
		if c.combat.weapon != "prison_shiv":
			v *= float(m["gear"])
	if c.job != null:
		v *= float(m["working"])
	v *= sim.squads.role_mult(c.id, "threat_mult")  # region C1: Bulwark draws, Medic hides
	v *= maxf(0.05, 1.0 + sim.passives.mod(c, "target_weight"))  # region F11W3 (cache refreshes with the candidate epoch)
	var cf := sim.abilities.flags_of(c.id)  # region C2: insertion order is set by Abilities
	for f: String in cf:
		v *= float(cf[f][1])
	return v


func _pollution(cell: Vector2i) -> float:
	return sim.mutation.value_at(cell) if sim.mutation != null else 0.0


## Rebuild the candidate cache (values incl. pollution and regional cap).
func refresh(force := false) -> void:
	if not force and sim.tick - _cache_tick < int(cfg["recompute_ticks"]):
		return
	_cache_tick = sim.tick
	_d0 = float(cfg["d0"])  # region W2d
	_line_on = bool(sim.defs.balance["line_damage"]["enabled"])
	_kind.clear()
	_id.clear()
	_ref.clear()
	_val.clear()
	_type.clear()
	_index.clear()  # region W1a
	_geo.clear()
	_bias_cache.clear()
	var kp := float(cfg["k_poll"])
	var rs := maxi(1, int(cfg["region_size"]))
	var sums: Dictionary = {}
	for b in sim.buildings.list:
		if b.destroyed:
			continue
		var v := building_value(b)
		if v <= 0.0:
			continue
		if _b2_ignores(b):  # region B2
			continue
		if b.def.get("sapper_only", false) and not b.def.has("threat"):
			continue
		v += _pollution(b.cell) * kp
		_kind.append(0)
		_id.append(b.id)
		_ref.append(b)
		_val.append(v)
		_type.append(b.def_id)
		_geo.append(b.cell.x)  # region W1a
		_geo.append(b.cell.y)
		_geo.append(b.size.x)
		_geo.append(b.size.y)
		var rk := (b.cell.x / rs) * 100003 + (b.cell.y / rs)
		sums[rk] = float(sums.get(rk, 0.0)) + v
	var cap := float(cfg["cap_per_region"])
	for i in _val.size():
		var b: Building = _ref[i]
		var rk := (b.cell.x / rs) * 100003 + (b.cell.y / rs)
		if sums[rk] > cap:
			_val[i] *= cap / sums[rk]
	_refresh_belts()  # region R3X
	_belt_lo = _val.size()  # region W1a
	for bc: Array in _belts:
		_kind.append(2)
		_id.append(int(bc[0]))
		_ref.append(bc[1])
		_val.append(float(cfg["base"].get("belt", 0.0)) * minf(sqrt(float(bc[2])), float(cfg.get("belt_scale_cap", 4.0))))
		_type.append("belt")
		_geo.append(0)  # region W1a
		_geo.append(0)
		_geo.append(0)
		_geo.append(0)
	_belt_hi = _val.size()  # region W1a
	_build_belt_grid(rs)
	for c in sim.colonists.list:
		if not c.alive or c.hidden:
			continue
		_kind.append(1)
		_id.append(c.id)
		_ref.append(c)
		_val.append(colonist_value(c) + _pollution(c.cell) * kp)
		_type.append("colonist")
		_geo.append(0)  # region W1a
		_geo.append(0)
		_geo.append(0)
		_geo.append(0)
	for i in _val.size():  # region W1a
		_index[(_kind[i] << 32) | _id[i]] = i
	# region W2d: identical candidates (same ids, values, geometry, refs) keep the per-enemy pick memos alive
	if _kind != _p_kind or _id != _p_id or _val != _p_val or _geo != _p_geo or _ref != _p_ref:
		_cand_gen += 1
		_p_kind = _kind.duplicate()
		_p_id = _id.duplicate()
		_p_val = _val.duplicate()
		_p_geo = _geo.duplicate()
		_p_ref = _ref.duplicate()
	# endregion


# region W1a
func _build_belt_grid(rs: int) -> void:
	_belt_rx.clear()
	_belt_ry.clear()
	_belt_max = 0.0
	_cand_di.clear()
	_belts_grid_ref = sim.logistics.belts
	_bgw = (sim.map.width + rs - 1) / rs
	_bgh = (sim.map.height + rs - 1) / rs
	_belt_grid.resize(_bgw * _bgh)
	_belt_grid.fill(-1)
	_g_x.resize(_bgw * _bgh)
	_g_y.resize(_bgw * _bgh)
	_g_di.resize(_bgw * _bgh)
	_g_val.resize(_bgw * _bgh)
	for i in range(_belt_lo, _belt_hi):
		var bc: Vector2i = _ref[i]
		var rx := bc.x / rs
		var ry := bc.y / rs
		_cand_di.append(bc.y * sim.logistics.belts.width + bc.x)
		_belt_rx.append(rx)
		_belt_ry.append(ry)
		var gi := ry * _bgw + rx
		_belt_grid[gi] = i
		_g_x[gi] = bc.x
		_g_y[gi] = bc.y
		_g_di[gi] = bc.y * sim.logistics.belts.width + bc.x
		_g_val[gi] = _val[i]
		_belt_max = maxf(_belt_max, _val[i])


## Best belt candidate for `e` (score > best_s, lowest index on ties), ring walk over the region grid with an
## exact upper bound; returns [index, score] via out params in `_bb`.
var _bb_i := -1
var _bb_s := 0.0


func _best_belt(e: Enemy, best_s: float, best_i: int, bias: float, d0: float) -> void:
	# Memo: the best belt for a cell does not depend on best_s/best_i (they only decide whether it wins), and it only
	# changes when the belt set changes (place/remove/destroy => belt_count/destroyed) or the candidates are rebuilt.
	var bg := _belts_grid_ref
	var sig := bg.version + _belt_tick * 7919 + _cache_tick * 104729  # place/remove or candidate rebuild
	if sig != _memo_sig:
		_memo_sig = sig
		_memo.clear()
	if not _memo.has(bias):
		_memo[bias] = {}
	var by_cell: Dictionary = _memo[bias]
	var mk := e.cell.y * bg.width + e.cell.x
	var hit: Array = by_cell.get(mk, [])
	if not hit.is_empty() and hit[0] >= 0:
		var hc := _cand_di[hit[0] - _belt_lo]
		if bg.dir[hc] == 255:  # the cached winner was destroyed since
			hit = []
	if hit.is_empty():
		_bdir = bg.dir
		_bw = bg.width
		_search_belt(e, 0.0, -1, bias, d0)
		hit = [_bb_i, _bb_s]
		by_cell[mk] = hit
	var hi: int = hit[0]
	var hs: float = hit[1]
	_bb_i = best_i
	_bb_s = best_s
	if hi >= 0 and (hs > best_s or (hs == best_s and hs > 0.0 and hi < best_i)):
		_bb_i = hi
		_bb_s = hs


func _search_belt(e: Enemy, best_s: float, best_i: int, bias: float, d0: float) -> void:
	_bb_i = best_i
	_bb_s = best_s
	var rs := maxi(1, int(cfg["region_size"]))
	var ex := e.cell.x / rs
	var ey := e.cell.y / rs
	var kmax := maxi(maxi(absi(ex), absi(_bgw - 1 - ex)), maxi(absi(ey), absi(_bgh - 1 - ey)))
	var cx := e.cell.x
	var cy := e.cell.y
	for k in kmax + 1:
		if k > 0 and _bb_s > 0.0:
			# exact lower bound of the distance to any cell of ring k (nearest of its four sides)
			var dm := mini(mini((ex + k) * rs - cx, cx - ((ex - k) * rs + rs - 1)),
					mini((ey + k) * rs - cy, cy - ((ey - k) * rs + rs - 1)))
			var dmin := float(maxi(dm, 0)) / d0
			if _belt_max * bias / (1.0 + dmin * dmin) * 1.0001 < _bb_s:
				return
		var x0 := ex - k
		var x1 := ex + k
		var y0 := ey - k
		var y1 := ey + k
		for ry in range(maxi(y0, 0), mini(y1, _bgh - 1) + 1):
			if ry == y0 or ry == y1:
				for rx in range(maxi(x0, 0), mini(x1, _bgw - 1) + 1):
					_try_belt(rx, ry, cx, cy, bias, d0)
			else:
				if x0 >= 0:
					_try_belt(x0, ry, cx, cy, bias, d0)
				if x1 < _bgw and x1 != x0:
					_try_belt(x1, ry, cx, cy, bias, d0)


func _try_belt(rx: int, ry: int, cx: int, cy: int, bias: float, d0: float) -> void:
	var gi := ry * _bgw + rx
	var i := _belt_grid[gi]
	if i < 0 or _bdir[_g_di[gi]] == 255:  # no candidate / !has_belt (enemy part of _belt_ok is checked once per pick)
		return
	var dx := _g_x[gi] - cx
	var dy := _g_y[gi] - cy
	var n := dx * dx + dy * dy
	if n >= _dist_tab.size():
		_grow_dist(n)
	var r := _dist_tab[n] / d0
	var s := _g_val[gi] * bias / (1.0 + r * r)
	if s > _bb_s or (s == _bb_s and s > 0.0 and i < _bb_i):
		_bb_s = s
		_bb_i = i


func _grow_dist(n: int) -> void:
	var from := _dist_tab.size()
	var to := maxi(n + 1, from + 4096)
	_dist_tab.resize(to)
	for k in range(from, to):
		_dist_tab[k] = sqrt(float(k))
# endregion


# region R3X
## Belt tiles are targets too (base.belt): one candidate per region = first belt in scan order.
func _refresh_belts() -> void:
	var belts := sim.logistics.belts
	if belts.belt_count == 0 or float(cfg["base"].get("belt", 0.0)) <= 0.0:
		_belts.clear()
		return
	if sim.tick - _belt_tick < int(cfg.get("belt_recompute_ticks", 60)) and not _belts.is_empty():
		return
	_belt_tick = sim.tick
	_belts.clear()
	var rs := maxi(1, int(cfg["region_size"]))
	var by_region: Dictionary = {}
	var w := belts.width
	var d := belts.dir
	for i in d.size():
		if d[i] == 255:
			continue
		var c := Vector2i(i % w, i / w)
		var rk := (c.x / rs) * 100003 + (c.y / rs)
		if by_region.has(rk):
			by_region[rk][2] += 1
		else:
			by_region[rk] = [rk, c, 1]
	var keys: Array = by_region.keys()
	keys.sort()
	for k in keys:
		_belts.append(by_region[k])


func _belt_ok(c: Vector2i, e: Enemy) -> bool:
	return e.structure_dmg > 0.0 and _line_on and sim.logistics.belts.has_belt(c)  # region W2d
# endregion


func score(i: int, e: Enemy) -> float:
	_flags_live = not sim.abilities.flags.is_empty()  # region W2d
	return _score(i, e, _entry_for(e)[0], float(cfg["d0"]))


## region W1a: `bias` (species bias per candidate, see _bias_for) and `d0` are hoisted out of the loop; distances of
## integer deltas come from the float32 sqrt table (bit-identical to Vector2.distance_to).
func _score(i: int, e: Enemy, bias: PackedFloat64Array, d0: float) -> float:
	var d: float
	var val := _val[i]
	var k := _kind[i]
	if k == 0:
		if (_ref[i] as Building).destroyed:
			return -1.0
		var g := i * 4
		var bx := _geo[g]
		var by := _geo[g + 1]
		var dx := clampi(e.cell.x, bx, bx + _geo[g + 2] - 1) - e.cell.x
		var dy := clampi(e.cell.y, by, by + _geo[g + 3] - 1) - e.cell.y
		var n := dx * dx + dy * dy
		if n >= _dist_tab.size():
			_grow_dist(n)
		d = _dist_tab[n]
	elif k == 2:  # region R3X
		var bc: Vector2i = _ref[i]
		if not _belt_ok(bc, e):
			return -1.0
		d = Vector2(bc).distance_to(Vector2(e.cell))
	else:
		var c: Colonist = _ref[i]
		if not c.alive or c.hidden:
			return -1.0
		d = Vector2(c.cell).distance_to(Vector2(e.cell))
		if _flags_live:  # region C2: radius-limited flags (taunt) fade beyond their radius
			var cf := sim.abilities.flags_of(c.id)
			for f: String in cf:
				var fl: Array = cf[f]
				if float(fl[2]) > 0.0 and d > float(fl[2]):
					val /= float(fl[1])
	var r := d / d0
	return val * bias[i] / (1.0 + r * r)


## Per enemy species: [bias per candidate, order, bounds, belt bias, can bite structures]. `order` lists the static
## candidates (buildings, and -1 for the whole belt group) by descending upper bound (value * bias); colonists are
## scored live. Rebuilt lazily after each refresh.
func _entry_for(e: Enemy) -> Array:
	var key := e.def_id
	if _bias_cache.has(key):
		return _bias_cache[key]
	var sb: Dictionary = cfg["species_bias"].get(e.def_id, {})
	var arr := PackedFloat64Array()
	arr.resize(_val.size())
	var ub: Array = []  # [-bound, index] sorts by descending bound then ascending index
	for i in _val.size():
		var bias := float(sb[_type[i]]) if sb.has(_type[i]) else 1.0
		arr[i] = bias
		if _kind[i] == 0:
			ub.append([-(_val[i] * bias), i])
	if _belt_hi > _belt_lo:
		ub.append([-(_belt_max * float(sb.get("belt", 1.0))), -1])
	ub.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var order := PackedInt32Array()
	var bounds := PackedFloat64Array()
	for u: Array in ub:
		order.append(u[1])
		bounds.append(-u[0])
	var entry := [arr, order, bounds, float(sb.get("belt", 1.0)), float(e.def.get("structure_dmg", 0.0)) > 0.0]
	_bias_cache[key] = entry
	return entry


## Best candidate for `e` among the static ones (buildings + belts), memoised per species and cell for the whole
## refresh epoch: those values never rise within an epoch (destruction only lowers them), so a remembered winner
## whose score is unchanged is still the argmax. Returns the candidate index (-1 none), score in _nc_s.
var _nc_s := 0.0
var _nc_epoch := -1
var _nc_sig := -1
var _nc: Dictionary = {}  # def_id -> {cell index -> [best, score]}


func _best_static(e: Enemy, entry: Array, d0: float) -> int:
	var bias: PackedFloat64Array = entry[0]
	var sig := sim.logistics.belts.version
	if _nc_epoch != _cache_tick or _nc_sig != sig:
		_nc_epoch = _cache_tick
		_nc_sig = sig
		_nc.clear()
	if not _nc.has(e.def_id):
		_nc[e.def_id] = {}
	var pm: Dictionary = _nc[e.def_id]
	var pk := e.cell.y * sim.map.width + e.cell.x
	var ph: Array = pm.get(pk, [])
	if not ph.is_empty() and _score(ph[0], e, bias, d0) == ph[1]:
		_nc_s = ph[1]
		return ph[0]
	var order: PackedInt32Array = entry[1]
	var bounds: PackedFloat64Array = entry[2]
	var best := -1
	var best_s := 0.0
	var belts_ok: bool = _belt_hi > _belt_lo and entry[4] and bool(sim.defs.balance["line_damage"]["enabled"])
	for j in order.size():
		if bounds[j] * 1.0001 < best_s:
			break  # sorted: nothing further can reach best_s
		var i := order[j]
		if i < 0:
			if belts_ok:
				_best_belt(e, best_s, best, entry[3], d0)
				if _bb_i != best:
					best_s = _bb_s
					best = _bb_i
			continue
		var s := _score(i, e, bias, d0)
		if s > best_s or (s == best_s and s > 0.0 and i < best):
			best_s = s
			best = i
	if best >= 0:
		pm[pk] = [best, best_s]
	_nc_s = best_s
	return best


## Best target for `e` honouring stickiness. {} when nothing is worth attacking.
## region W1a: same result as scanning every candidate in index order (strict >, first max wins): static candidates
## come from _best_static, colonists (highest indices) are scored live and win only with a strictly higher score.
func pick(e: Enemy) -> Dictionary:
	refresh()
	# region W2d: per-enemy memo. The result is a pure function of (candidate epoch, belt set, enemy cell, sticky target)
	# as long as no colonist can out-score the winner (checked once when storing) and no ability flag is live.
	var bgv := sim.logistics.belts.version
	if _cand_gen != _gen_cache or bgv != _gen_ver:
		_gen_cache = _cand_gen
		_gen_ver = bgv
		_gen += 1
	var flagged := not sim.abilities.flags.is_empty()  # ability flags are read live and may raise a score
	_flags_live = flagged
	if e.pk_gen == _gen and not flagged and e.pk_cell == e.cell and e.pk_tk == e.target_kind and e.pk_tid == e.target_id \
			and e.pk_tcell == e.target_cell and (e.pk_bld == null or not e.pk_bld.destroyed):
		# Static part unchanged; colonists move, so they are re-scored live: the memo holds while none beats the winner.
		var held := true
		var pbias := e.pk_bias
		var ps := e.pk_s
		var ex := e.cell.x
		var ey := e.cell.y
		var d0sq := _d0 * _d0
		for i in range(_belt_hi, _val.size()):
			var vb := _val[i] * pbias[i]
			if vb * 1.0001 < ps:
				continue
			var c: Colonist = _ref[i]
			if not c.alive or c.hidden:
				continue
			var dx := c.cell.x - ex
			var dy := c.cell.y - ey
			if float(dx * dx + dy * dy) >= d0sq * (vb / ps) * 1.001:  # score = vb / (1 + d2/d0sq) < ps for sure
				continue
			if _score(i, e, pbias, _d0) > ps:
				held = false
				break
		if held:
			return e.pk_res
	var cur := -1
	if e.target_kind != Enemy.Target.NONE:
		var ek := 0 if e.target_kind == Enemy.Target.BUILDING else (2 if e.target_kind == Enemy.Target.BELT else 1)
		cur = int(_index.get((ek << 32) | e.target_id, -1))
	var entry := _entry_for(e)
	var bias: PackedFloat64Array = entry[0]
	var d0 := _d0
	var best := _best_static(e, entry, d0)
	var best_s := _nc_s
	for i in range(_belt_hi, _val.size()):
		if not flagged and _val[i] * bias[i] * 1.0001 < best_s:
			continue
		var s := _score(i, e, bias, d0)
		if s > best_s:
			best_s = s
			best = i
	var res := _finish(e, best, best_s, cur)
	# Keep fixed points only (the result is the target the enemy already has, which the caller stores as the next sticky
	# target) whose static winner no colonist beat; see the hit check above.
	e.pk_gen = -1
	if not flagged and cur >= 0 and best >= 0 and _kind[best] != 1 and not res.is_empty() and (_kind[cur] == 0 or _kind[cur] == 2) \
			and int(res["id"]) == _id[cur] and (res["kind"] == "belt") == (_kind[cur] == 2):
		e.pk_gen = _gen
		e.pk_cell = e.cell
		e.pk_tk = e.target_kind
		e.pk_tid = e.target_id
		e.pk_tcell = e.target_cell
		e.pk_res = res
		e.pk_s = best_s
		e.pk_bias = bias
		e.pk_bld = _ref[cur] if _kind[cur] == 0 else null
	return res


## Stickiness to the current target `cur` (candidate index or -1) and the result dictionary for the best candidate.
func _finish(e: Enemy, p_best: int, best_s: float, cur: int) -> Dictionary:
	var best := p_best
	if best < 0:
		return {}
	var cur_s := -1.0
	if cur >= 0 and cur != best:
		cur_s = score(cur, e)  # lazily: only needed when the best candidate is another one
		if cur_s <= 0.0:
			cur = -1
	if cur >= 0 and cur != best:
		var pr: Dictionary = cfg["pull_ratio"]
		var pull := float(pr["ranged"] if e.def.get("ranged", false) else pr["melee"])
		if cur_s >= float(cfg["stick"]) * best_s or best_s <= pull * cur_s:
			best = cur
	if _kind[best] == 2:  # region R3X
		return {"kind": "belt", "id": _id[best], "cell": _ref[best]}
	return {"kind": "building" if _kind[best] == 0 else "colonist", "id": _id[best]}


func _belt_ok_enemy(e: Enemy) -> bool:
	return float(e.def.get("structure_dmg", 0.0)) > 0.0 and bool(sim.defs.balance["line_damage"]["enabled"])


## Score of a specific building for `e` (tests, decoy tools); uses a fresh cache.
func score_building(b: Building, e: Enemy) -> float:
	refresh(true)
	for i in _val.size():
		if _kind[i] == 0 and _id[i] == b.id:
			return score(i, e)
	return 0.0


# region B2
## Creatures ignore mining outposts while the planet is clean (threat.json b2_clean_outpost).
func _b2_ignores(b: Building) -> bool:
	var c: Dictionary = cfg.get("b2_clean_outpost", {})
	return bool(c.get("enabled", false)) and c["types"].has(b.def_id) \
		and sim.contamination.fraction() <= float(c["max_pollution_frac"])
# endregion
