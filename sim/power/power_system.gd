class_name PowerSystem
extends RefCounted
## L3: electricity. Poles link into networks (union-find, recomputed only when `buildings.version`
## changes); generators burn fuel from `data/fuels.json` only while their network has demand;
## brownout factor = clamp(supply / demand, min_factor, 1) scales processor work steps and extractor
## output. Consumers outside every pole range run at `unpowered_factor`. Enforcement stays OFF
## (factor 1, no state in the hash) until the first pole or generator is built.
## API for the view/data layers: docs/power_api.md.
##
## Building defs (data/buildings.json): consumer `power_use`; generator `power_gen` + `fuel`
## ({item, burn_ticks, waste_per_burn} | item id | null for passive) + optional `meltdown`
## {fuse_ticks, condition_below, radius, damage, contamination} and `wear_per_burn`; pole `power_range`.
## Fuel entries (data/fuels.json, read generically, every field optional): burn_ticks | energy,
## waste (alias waste_per_burn), contamination, spent_item, spent_per_burn.
## Balance (`balance.power`, all optional): min_factor 0.2, unpowered_factor 0.5, chip_use 10, bucket 0.05.

var sim: Simulation
var enabled := false
var version := 0  ## bumps whenever the topology is rebuilt (view: redraw wires)
## Static network dicts, ascending id: {id, poles: Array of building ids, gens: Array[Building],
## users: Array[Building]}; live supply/demand/factor via `net_info(id)`.
var nets: Array[Dictionary] = []
## Flat [pole_id, other_id, ...] wire list for the view (pole-pole links and each building to its first pole).
var links: PackedInt32Array = PackedInt32Array()  # flat pairs: [a0, b0, a1, b1, ...]
var _ver := -1
var _min := 0.2
var _unpowered := 0.5
var _chip_use := 10.0
var _bucket := 0.05
var _users: Array[Building] = []
var _ukind := PackedByteArray()  # 0 extractor, 1 processor, 2 other (bench)
var _ucap := PackedInt32Array()
var _uuse := PackedFloat32Array()
var _gens: Array[Building] = []
var _net_factor: PackedFloat32Array = PackedFloat32Array()
var _net_supply: PackedFloat32Array = PackedFloat32Array()
var _net_demand: PackedFloat32Array = PackedFloat32Array()
var _last_bucket: Dictionary = {}  # net id -> bucket
var _dsu := PowerNet.new()
var _kinds: Dictionary = {}
const FWD_X: Array[int] = [0, 1, 1, 1, 0]
const FWD_Y: Array[int] = [0, -1, 0, 1, 1]


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	var c: Dictionary = p_sim.defs.balance.get("power", {})
	_min = float(c.get("min_factor", 0.2))
	_unpowered = float(c.get("unpowered_factor", 0.5))
	_chip_use = float(c.get("chip_use", 10.0))
	_bucket = float(c.get("bucket", 0.05))


# --- Queries (view / other systems) ---------------------------------------------

## Multiplier on this building's work speed: 1.0 while enforcement is off.
func factor_for(b: Building) -> float:
	if not enabled or b.power_net < -1:
		return 1.0
	if b.power_net < 0:
		return _unpowered
	return _net_factor[b.power_net]


## Processor steps scaled by the brownout factor (fractional accumulator, deterministic).
func scale_steps(b: Building, steps: int) -> int:
	if not enabled or steps <= 0 or b.power_net < -1:
		return steps
	var f := factor_for(b)
	if f >= 1.0:
		return steps
	b.power_acc += float(steps) * f
	var n := int(floor(b.power_acc + 0.0001))
	b.power_acc -= n
	return n


func net_id_of(b: Building) -> int:
	return int(nets[b.power_net]["id"]) if b.power_net >= 0 and b.power_net < nets.size() else -1


## Network snapshot {id, poles, gens, users, supply, demand, factor} (live per-tick values), {} if unknown.
func net_info(id: int) -> Dictionary:
	for i in nets.size():
		if int(nets[i]["id"]) == id:
			var d: Dictionary = nets[i].duplicate()
			d["supply"] = _net_supply[i]
			d["demand"] = _net_demand[i]
			d["factor"] = _net_factor[i]
			return d
	return {}


## Lowest factor over all networks (1.0 when none) and its net id (-1): the HUD chip.
func worst_net() -> Dictionary:
	var best := -1
	for i in nets.size():
		if best < 0 or _net_factor[i] < _net_factor[best]:
			best = i
	return net_info(int(nets[best]["id"])) if best >= 0 else {}


func is_generator(b: Building) -> bool:
	return float(b.def.get("power_gen", 0.0)) > 0.0


func is_pole(b: Building) -> bool:
	return b.def.has("power_range")


func fuel_items(b: Building) -> Array[String]:
	var out: Array[String] = []
	var f: Variant = b.def.get("fuel", null)
	if f is Dictionary:
		if f.has("items"):
			for i in f["items"]:
				out.append(str(i))
		elif f.has("item"):
			out.append(str(f["item"]))
	elif f is String:
		out.append(f)
	return out


func fuel_entry(item: String) -> Dictionary:
	var all: Dictionary = sim.defs.fuels
	if all.has("fuels") and all["fuels"] is Dictionary:
		all = all["fuels"]
	return all.get(item, {})


## Units of fuel in the input buffer (all accepted fuel items).
func fuel_left(b: Building) -> int:
	var n := 0
	for it in fuel_items(b):
		n += int(b.input.get(it, 0))
	return n


func burning(b: Building) -> bool:
	return b.burn_left > 0


## Generator output right now (0 when broken or out of fuel; passive ones always).
func supply_of(b: Building) -> float:
	if b.broken or b.destroyed or not is_generator(b):
		return 0.0
	if fuel_items(b).is_empty():
		return gen_of(b)
	return gen_of(b) if b.burn_left > 0 or fuel_left(b) > 0 else 0.0


## Waste units per 1000 ticks if the generator burned continuously (for panels).
func waste_per_1000(b: Building) -> float:
	var items := fuel_items(b)
	if items.is_empty():
		return 0.0
	var p := _burn_params(b, items[0])
	return float(p["waste"]) * 1000.0 / maxf(1.0, float(p["ticks"]))


func state_parts() -> Array:
	if not enabled:
		return []
	var parts: Array = [true]
	for b in sim.buildings.list:
		if b.burn_left != 0 or b.heat != 0 or b.waste_acc != 0.0 or b.power_acc != 0.0:
			parts.append([b.id, b.burn_left, b.heat, b.waste_acc, b.power_acc])
	return parts


# --- Tick ---------------------------------------------------------------------------

func tick() -> void:
	if sim.buildings.version != _ver:
		_rebuild()
	if not enabled:
		return
	var n := nets.size()
	var demand := PackedFloat32Array()
	demand.resize(n)
	var bench_on := false
	var bench_checked := false
	var has_chips := not sim.chips.slots.is_empty()
	for i in _users.size():
		var u := _users[i]
		if u.broken or u.power_net < 0:
			continue
		var kind := _ukind[i]
		var active := false
		if kind == 1:
			active = u.progress > 0 or (not u.input.is_empty() and u.output_total() < _ucap[i])
		elif kind == 0:
			active = u.output_total() < _ucap[i]
		else:
			if not bench_checked:
				bench_checked = true
				bench_on = ResearchOperator.active(sim) != ""
			active = bench_on
		if not active:
			continue
		var use := _uuse[i]
		if has_chips and sim.chips.slots.has(u.id):
			use += _chip_use
		demand[u.power_net] += use
	var supply := PackedFloat32Array()
	supply.resize(n)
	for g in _gens:
		_tick_generator(g, demand, supply)
	_net_supply = supply
	_net_demand = demand
	for i in n:
		var f := 1.0
		if demand[i] > 0.0:
			f = clampf(supply[i] / demand[i], _min, 1.0)
		_net_factor[i] = f
		var bk := int(round(f / _bucket))
		var id := int(nets[i]["id"])
		if int(_last_bucket.get(id, bk)) != bk:
			sim.bus.power_changed.emit(id)
		_last_bucket[id] = bk


func _tick_generator(g: Building, demand: PackedFloat32Array, supply: PackedFloat32Array) -> void:
	if g.destroyed:
		return
	var items := fuel_items(g)
	var cap := gen_of(g)
	var net := g.power_net
	var want := net >= 0 and demand[net] > 0.0
	if items.is_empty():  # passive (solar)
		if net >= 0 and not g.broken:
			supply[net] += cap
		return
	var has_fuel := g.burn_left > 0 or fuel_left(g) > 0
	if not g.broken and want:
		if g.burn_left <= 0 and fuel_left(g) > 0:
			_start_burn(g, items)
		if g.burn_left > 0:
			g.burn_left -= 1
			supply[net] += cap
	elif not g.broken and net >= 0 and has_fuel:
		supply[net] += cap  # idle: nothing burns; potential output keeps the factor at 1
	_set_flags(g, g.burn_left > 0 and want, has_fuel)
	_meltdown_check(g, has_fuel)


func _start_burn(g: Building, items: Array[String]) -> void:
	var item := ""
	for it in items:
		if int(g.input.get(it, 0)) > 0:
			item = it
			break
	g.input[item] = int(g.input[item]) - 1
	if g.input[item] <= 0:
		g.input.erase(item)
	sim.ledger.record_consumed(item, 1, "power_fuel")
	var p := _burn_params(g, item)
	g.burn_left = int(p["ticks"])
	g.waste_acc += float(p["waste"])
	var whole := int(floor(g.waste_acc + 0.0001))
	if whole > 0:
		g.waste_acc -= whole
		_emit(g, "waste", whole, "power_waste")
	var spent := str(p["spent_item"])
	if spent != "" and sim.defs.items.has(spent):
		_emit(g, spent, int(p["spent_n"]), "power_spent")
	var contam := float(p["contamination"])
	if contam > 0.0 and sim.contamination != null:
		sim.contamination.level += contam
	var wear := float(g.def.get("wear_per_burn", 0.0))
	if wear > 0.0:
		sim.buildings.wear(g, wear)


func _burn_params(g: Building, item: String) -> Dictionary:
	var e := fuel_entry(item)
	var f: Variant = g.def.get("fuel", null)
	var fd: Dictionary = f if f is Dictionary else {}
	var ticks := int(e.get("burn_ticks", fd.get("burn_ticks", 0)))
	if ticks <= 0 and e.has("energy"):  # energy per unit (power x seconds) -> ticks at the generator's output
		ticks = int(round(float(e["energy"]) / maxf(0.001, gen_of(g)) * Simulation.TICKS_PER_SECOND))
	return {
		"ticks": maxi(1, ticks),
		"waste": float(e.get("waste", e.get("waste_per_burn", fd.get("waste_per_burn", 0.0)))),
		"contamination": float(e.get("contamination", 0.0)),
		"spent_item": str(e.get("spent_item", "")),
		"spent_n": int(e.get("spent_per_burn", 1)),
	}


## Waste / spent fuel go to the output buffer while it has room, else onto the ground (always ledgered).
func _emit(g: Building, item: String, n: int, source: String) -> void:
	if n <= 0:
		return
	sim.ledger.record_produced(item, n, source)
	var room := maxi(0, int(g.def.get("output_capacity", 0)) - g.output_total())
	var k := mini(n, room)
	if k > 0:
		g.output[item] = int(g.output.get(item, 0)) + k
	if n > k:
		sim.items.drop(g.cell, item, n - k)


func _set_flags(g: Building, running: bool, has_fuel: bool) -> void:
	g.threat_flags["powered_gen"] = running
	g.threat_flags["unfuelled"] = not has_fuel


## Overheat: a reactor (def.meltdown) that is broken or worn down while fuelled heats up and,
## after `fuse_ticks`, melts down. Deterministic, no rng. Repairing in time cools it.
func _meltdown_check(g: Building, has_fuel: bool) -> void:
	var m: Dictionary = g.def.get("meltdown", {})
	if m.is_empty():
		return
	var hot := has_fuel and (g.broken or g.condition <= float(m.get("condition_below", 0.0)))
	if not hot:
		g.heat = maxi(0, g.heat - 2)
		return
	g.heat += 1
	if g.heat < int(m.get("fuse_ticks", 100)):
		return
	var radius := float(m.get("radius", 3.0))
	var dmg := float(m.get("damage", 100.0))
	var near: Array[Building] = []
	for o in sim.buildings.list:
		if o != g and o.distance_to(g.center()) <= radius:
			near.append(o)
	if sim.contamination != null:
		sim.contamination.level += float(m.get("contamination", 0.0))
	sim.ledger.record_event("power:meltdown", 1)
	sim.bus.power_meltdown.emit(g.id)
	sim.buildings.destroy(g)
	for o in near:
		sim.buildings.damage(o, dmg)


# --- Topology ---

## Per-def role cache: 0 none, 1 pole, 2 generator, 3 consumer.
func _kind_of(b: Building) -> int:
	if _kinds.has(b.def_id):
		return _kinds[b.def_id]
	var k := 0
	if is_pole(b):
		k = 1
	elif is_generator(b):
		k = 2
	elif float(b.def.get("power_use", 0.0)) > 0.0:
		k = 3
	_kinds[b.def_id] = k
	return k



func _rebuild() -> void:
	_ver = sim.buildings.version
	version += 1
	var poles: Array[Building] = []
	_users = []
	_gens = []
	for b in sim.buildings.list:
		b.power_net = -2  # -2: not part of the grid
		var kind := _kind_of(b)
		if kind == 0 or b.destroyed:
			continue
		if kind == 1:
			if not b.broken:
				poles.append(b)
		elif kind == 2:
			_gens.append(b)
		else:
			_users.append(b)
	if not enabled and poles.is_empty() and _gens.is_empty():
		return
	_ukind.resize(_users.size())
	_ucap.resize(_users.size())
	_uuse.resize(_users.size())
	for i in _users.size():
		var m := str(_users[i].def.get("machine", ""))
		_ukind[i] = 0 if m == "extractor" else (1 if m == "processor" else 2)
		_ucap[i] = int(_users[i].def.get("output_capacity", 0))
		_uuse[i] = float(_users[i].def["power_use"])
	enabled = true
	var np := poles.size()
	var centers := PackedVector2Array()
	var ranges := PackedFloat32Array()
	centers.resize(np)
	ranges.resize(np)
	var size := 3
	for i in np:
		centers[i] = Vector2(poles[i].cell) + Vector2(poles[i].size) * 0.5 - Vector2(0.5, 0.5)
		ranges[i] = float(poles[i].def["power_range"])
		size = maxi(size, int(ceil(ranges[i])))
	var buckets: Dictionary = {}
	for i in np:
		var k := PowerNet.key(floori(centers[i].x / size), floori(centers[i].y / size))
		if not buckets.has(k):
			buckets[k] = []
		buckets[k].append(i)
	_dsu.reset(np)
	links.clear()
	for i in np:
		var bx := floori(centers[i].x / size)
		var by := floori(centers[i].y / size)
		var ci := centers[i]
		var ri := ranges[i]
		for d in 5:  # own bucket (j > i) and the four forward neighbours: every pair is visited once
			var k := PowerNet.key(bx + FWD_X[d], by + FWD_Y[d])
			if not buckets.has(k):
				continue
			for j: int in buckets[k]:
				if d == 0 and j <= i:
					continue
				var cj := centers[j]
				var r := maxf(ri, ranges[j])
				var ddx := ci.x - cj.x
				var ddy := ci.y - cj.y
				if ddx * ddx + ddy * ddy <= r * r:
					_dsu.union(i, j)
					links.append(poles[i].id)
					links.append(poles[j].id)
	var reach: Dictionary = {}  # building id -> Array[int] of pole indices
	for arr: Array in [_users, _gens]:
		for b: Building in arr:
			var r := PowerNet.poles_in_reach(b, buckets, size, centers, ranges)
			reach[b.id] = r
			for q in range(1, r.size()):
				_dsu.union(r[0], r[q])
			if not r.is_empty():
				links.append(poles[r[0]].id)
				links.append(b.id)
	var root_net: Dictionary = {}
	nets = []
	for i in np:
		var root := _dsu.find(i)
		if not root_net.has(root):
			root_net[root] = nets.size()
			nets.append({"id": poles[root].id, "poles": [], "gens": [], "users": []})
		poles[i].power_net = int(root_net[root])
		nets[int(root_net[root])]["poles"].append(poles[i].id)
	_net_factor.resize(nets.size())
	_net_factor.fill(1.0)
	for arr: Array in [_users, _gens]:
		for b: Building in arr:
			var r: Array = reach[b.id]
			b.power_net = int(root_net[_dsu.find(r[0])]) if not r.is_empty() else -1
			if b.power_net >= 0:
				nets[b.power_net]["gens" if is_generator(b) else "users"].append(b)
	var kept: Dictionary = {}  # forget networks that no longer exist
	for net in nets:
		var id := int(net["id"])
		if _last_bucket.has(id):
			kept[id] = _last_bucket[id]
	_last_bucket = kept
	_net_supply.resize(nets.size())
	_net_demand.resize(nets.size())
	_net_supply.fill(0.0)
	_net_demand.fill(0.0)


# region K5
## Nominal output; with balance k5_enabled a def may override it via `k5_power_gen` (solar ~30% of a smelter).
func gen_of(b: Building) -> float:
	if b.def.has("k5_power_gen") and bool(sim.defs.balance.get("k5_enabled", false)):
		return float(b.def["k5_power_gen"])
	return float(b.def["power_gen"])
# endregion
