class_name PowerReader
extends RefCounted
## L4: view-side read adapter for the power grid (L3 owns `sim.power`). Every call is behind a
## has_method / get() guard, so the view works (shows nothing) before L3 is merged, and a test or
## screenshot tool can attach a PowerStub with `sim.set_meta("power_stub", stub)`.
##
## Calls expected from the grid object (`sim.power`):
##   power.version: int                      bumped on any topology change (poles/buildings placed, removed, broken)
##   power.networks() -> Array[Dictionary]   {id:int, supply:float, demand:float, factor:float,
##                                            poles:Array[int], generators:Array[int], consumers:Array[int]}  (building ids)
##   power.links() -> Array                  [[building_id_a, building_id_b], ...] one entry per wire
##   power.generator_info(id:int) -> Dictionary
##                                           {burning:bool, fuel:int, fuel_cap:int, fuel_item:String, supply:float,
##                                            overheat:float 0..1 (reactor, optional), waste_per_min:float (optional)}
##   signal bus.power_changed(net_id)        optional; the HUD refreshes on it, plus a 1 s timer
## net_of(id) and factor_of(id) are derived here from networks().

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


static func grid(sim: Simulation) -> Object:
	if sim == null:
		return null
	var g: Variant = sim.get("power")
	if g is Object and (g as Object).has_method("networks"):
		return g
	if sim.has_meta("power_stub"):
		var s: Variant = sim.get_meta("power_stub")
		if s is Object and (s as Object).has_method("networks"):
			return s
	return null


static func version(sim: Simulation) -> int:
	var g := grid(sim)
	if g == null:
		return -1
	var v: Variant = g.get("version")
	return int(v) if v != null else 0


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
	_nets = g.call("networks") as Array
	_net_of = {}
	for i in _nets.size():
		var n: Dictionary = _nets[i]
		for key: String in ["poles", "generators", "consumers"]:
			for id: Variant in n.get(key, []):
				_net_of[int(id)] = i
	_links = g.call("links") as Array if g.has_method("links") else []


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
	if g == null or not g.has_method("generator_info"):
		return {}
	var d: Variant = g.call("generator_info", building_id)
	return d if d is Dictionary else {}


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
