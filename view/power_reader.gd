class_name PowerReader
extends RefCounted
## L4: view-side read adapter over the real grid `sim.power` (PowerSystem, docs/power_api.md).
## Snapshots are cached and turned into plain dictionaries of building ids:
##   nets(): {id, supply, demand, factor, poles[], generators[], consumers[]}
##   links(): [[id_a, id_b], ...] one entry per wire
##   generator_info(id): {burning, fuel, fuel_cap, fuel_item, supply, overheat 0..1, waste_per_min}

## Generator building ids with a dedicated voxel model (own keys in data/models.json).
const GENERATORS: Array[String] = ["coal_generator", "nitrogen_turbine", "nuclear_reactor", "solar_array"]
const POLE := "power_pole"
const REFRESH_MSEC := 1000

static var overlay_on := false  ## player toggle (power panel); off by default

static var _sim_id := 0
static var _stamp := -1
static var _msec := 0
static var _nets: Array = []
static var _net_of := {}  # building id -> index into _nets
static var _links: Array = []


static func grid(sim: Simulation) -> PowerSystem:
	if sim == null or sim.power == null or not sim.power.enabled:
		return null
	return sim.power


static func version(sim: Simulation) -> int:
	var g := grid(sim)
	return -1 if g == null else g.version


## Cached snapshot: rebuilt when the grid version changes or after REFRESH_MSEC (factors drift).
static func refresh(sim: Simulation, force := false) -> void:
	var g := grid(sim)
	if g == null:
		_nets = []
		_net_of = {}
		_links = []
		_sim_id = 0
		return
	var now := Time.get_ticks_msec()
	var v := version(sim)
	if not force and sim.get_instance_id() == _sim_id and v == _stamp and now - _msec < REFRESH_MSEC:
		return
	_sim_id = sim.get_instance_id()
	_stamp = v
	_msec = now
	_nets = []
	_net_of = {}
	for raw: Dictionary in g.nets:
		var info := g.net_info(int(raw["id"]))
		var gens: Array = []
		for b: Building in raw.get("gens", []):
			gens.append(b.id)
		var users: Array = []
		for b: Building in raw.get("users", []):
			users.append(b.id)
		var n := {"id": info["id"], "supply": float(info["supply"]), "demand": float(info["demand"]),
			"factor": float(info["factor"]), "poles": (raw.get("poles", []) as Array).duplicate(),
			"generators": gens, "consumers": users}
		var i := _nets.size()
		_nets.append(n)
		for key: String in ["poles", "generators", "consumers"]:
			for id: Variant in n[key]:
				_net_of[int(id)] = i
	_links = []
	var fl := g.links
	for k in range(0, fl.size() - 1, 2):
		_links.append([fl[k], fl[k + 1]])


static func nets(sim: Simulation) -> Array:
	refresh(sim)
	return _nets


static func links(sim: Simulation) -> Array:
	refresh(sim)
	return _links


## Index of the building's network in nets(), -1 when it is on none.
static func net_index(sim: Simulation, building_id: int) -> int:
	refresh(sim)
	return int(_net_of.get(building_id, -1))


## Brownout factor of the building's net, 1.0 when unknown / unconnected.
static func factor_of(sim: Simulation, building_id: int) -> float:
	var i := net_index(sim, building_id)
	return 1.0 if i < 0 else float((_nets[i] as Dictionary).get("factor", 1.0))


static func generator_info(sim: Simulation, building_id: int) -> Dictionary:
	var g := grid(sim)
	var b: Building = null if g == null else sim.buildings.get_by_id(building_id)
	if b == null or not g.is_generator(b):
		return {}
	var items := g.fuel_items(b)
	var d := {"burning": g.burning(b) or items.is_empty() and g.supply_of(b) > 0.0,
		"fuel": g.fuel_left(b), "fuel_cap": int(b.def.get("input_capacity", 0)) if not items.is_empty() else 0,
		"fuel_item": "" if items.is_empty() else items[0], "supply": g.supply_of(b),
		"waste_per_min": g.waste_per_1000(b) * 60.0 * Simulation.TICKS_PER_SECOND / 1000.0}
	var m: Variant = b.def.get("meltdown", null)
	if m is Dictionary:
		d["overheat"] = clampf(float(b.heat) / maxf(1.0, float(m.get("fuse_ticks", 1))), 0.0, 1.0)
	return d


## Net with the lowest factor (ties: highest demand); {} when no poles exist.
static func worst_net(sim: Simulation) -> Dictionary:
	var best: Dictionary = {}
	for n: Dictionary in nets(sim):
		if (n.get("poles", []) as Array).is_empty():
			continue
		if best.is_empty() or float(n["factor"]) < float(best["factor"]) \
				or (float(n["factor"]) == float(best["factor"]) and float(n["demand"]) > float(best["demand"])):
			best = n
	return best


## "PWR 80/120 (67%)": supply / demand and the satisfied share. Fuel-less net reads "PWR 0/120 (0%)".
static func chip_text(net: Dictionary) -> String:
	if net.is_empty():
		return ""
	var sup := float(net["supply"])
	var dem := float(net["demand"])
	var pct := 100 if dem <= 0.0 else clampi(roundi(sup / dem * 100.0), 0, 100)
	return "PWR %d/%d (%d%%)" % [roundi(sup), roundi(dem), pct]


## Chip colour state: 0 ok, 1 brownout (factor < 0.9), 2 severe (< 0.5).
static func severity(factor: float) -> int:
	return 2 if factor < 0.5 else (1 if factor < 0.9 else 0)


static func severity_color(sev: int) -> Color:
	return [Color(0.55, 0.9, 0.55), Color(1.0, 0.85, 0.3), Color(1.0, 0.35, 0.3)][sev]


const NET_COLORS: Array[Color] = [Color("#5fd0ff"), Color("#7be07b"), Color("#d89bff"), Color("#ffb066"), Color("#6fe0c8"), Color("#e8e86a")]


static func net_color(index: int, factor: float) -> Color:
	if factor < 0.5:
		return Color("#ff4a3d")
	var c := NET_COLORS[maxi(index, 0) % NET_COLORS.size()]
	return c.lerp(Color("#ffd23a"), 0.55) if factor < 0.9 else c
