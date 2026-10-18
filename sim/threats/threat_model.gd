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
	return v


func _pollution(cell: Vector2i) -> float:
	return sim.mutation.value_at(cell) if sim.mutation != null else 0.0


## Rebuild the candidate cache (values incl. pollution and regional cap).
func refresh(force := false) -> void:
	if not force and sim.tick - _cache_tick < int(cfg["recompute_ticks"]):
		return
	_cache_tick = sim.tick
	_kind.clear()
	_id.clear()
	_ref.clear()
	_val.clear()
	_type.clear()
	var kp := float(cfg["k_poll"])
	var rs := maxi(1, int(cfg["region_size"]))
	var sums: Dictionary = {}
	for b in sim.buildings.list:
		if b.destroyed:
			continue
		var v := building_value(b)
		if v <= 0.0:
			continue
		if b.def.get("sapper_only", false) and not b.def.has("threat"):
			continue
		v += _pollution(b.cell) * kp
		_kind.append(0)
		_id.append(b.id)
		_ref.append(b)
		_val.append(v)
		_type.append(b.def_id)
		var rk := (b.cell.x / rs) * 100003 + (b.cell.y / rs)
		sums[rk] = float(sums.get(rk, 0.0)) + v
	var cap := float(cfg["cap_per_region"])
	for i in _val.size():
		var b: Building = _ref[i]
		var rk := (b.cell.x / rs) * 100003 + (b.cell.y / rs)
		if sums[rk] > cap:
			_val[i] *= cap / sums[rk]
	for c in sim.colonists.list:
		if not c.alive or c.hidden:
			continue
		_kind.append(1)
		_id.append(c.id)
		_ref.append(c)
		_val.append(colonist_value(c) + _pollution(c.cell) * kp)
		_type.append("colonist")


func score(i: int, e: Enemy) -> float:
	var d: float
	if _kind[i] == 0:
		var b: Building = _ref[i]
		if b.destroyed:
			return -1.0
		d = b.distance_to(Vector2(e.cell))
	else:
		var c: Colonist = _ref[i]
		if not c.alive or c.hidden:
			return -1.0
		d = Vector2(c.cell).distance_to(Vector2(e.cell))
	var r := d / float(cfg["d0"])
	var bias := 1.0
	var sb: Dictionary = cfg["species_bias"].get(e.def_id, {})
	if sb.has(_type[i]):
		bias = float(sb[_type[i]])
	return _val[i] * bias / (1.0 + r * r)


## Best target for `e` honouring stickiness. {} when nothing is worth attacking.
func pick(e: Enemy) -> Dictionary:
	refresh()
	var best := -1
	var best_s := 0.0
	var cur := -1
	var cur_s := -1.0
	for i in _val.size():
		var s := score(i, e)
		if s <= 0.0:
			continue
		if _kind[i] == (0 if e.target_kind == Enemy.Target.BUILDING else 1) and _id[i] == e.target_id \
				and e.target_kind != Enemy.Target.NONE:
			cur = i
			cur_s = s
		if s > best_s:
			best_s = s
			best = i
	if best < 0:
		return {}
	if cur >= 0 and cur != best:
		var pr: Dictionary = cfg["pull_ratio"]
		var pull := float(pr["ranged"] if e.def.get("ranged", false) else pr["melee"])
		if cur_s >= float(cfg["stick"]) * best_s or best_s <= pull * cur_s:
			best = cur
	return {"kind": "building" if _kind[best] == 0 else "colonist", "id": _id[best]}


## Score of a specific building for `e` (tests, decoy tools); uses a fresh cache.
func score_building(b: Building, e: Enemy) -> float:
	refresh(true)
	for i in _val.size():
		if _kind[i] == 0 and _id[i] == b.id:
			return score(i, e)
	return 0.0
