class_name Campaign
extends RefCounted
## Several Simulations ("maps") under one clock. Only the active map steps for real;
## unattended outposts advance analytically once per day (Autopilot). No Node, no autoload.
## Home = map 0, seed = campaign_seed, so Campaign.new(s) home == Simulation.new(s).

var campaign_seed: int
var defs: Defs
var opts: Dictionary
var cfg: Dictionary
var tick := 0
var active := 0
var maps: Array = []  # {id, biome, sim, kind, seed, opts}
var log: Array = []  # [tick, name, args]
var in_flight: Array = []  # sling crates (W4)
var ledgers: Dictionary = {}  # map id -> Autopilot ledger (plain data)
var home_debt_charged := 0
var _bus_factory: Callable
var _ticks_per_day := 600


func _init(p_seed: int, bus_factory: Callable, p_defs: Defs = null, p_opts := {}) -> void:
	campaign_seed = p_seed
	_bus_factory = bus_factory
	defs = p_defs if p_defs != null else Defs.get_default()
	opts = p_opts.duplicate(true)
	cfg = load_cfg()
	_ticks_per_day = int(defs.balance["ticks_per_day"])


static func load_cfg() -> Dictionary:
	var f := FileAccess.open("res://data/expedition.json", FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func outpost_seed(p_seed: int, k: int) -> int:
	return p_seed * 1000003 + k * 7919


## Creates the home map (id 0).
func start() -> void:
	var sim := Simulation.new(campaign_seed, _bus_factory.call(), defs, opts.get("home_opts", {}))
	sim.start_new_game()
	maps.append({"id": 0, "biome": "start", "sim": sim, "kind": "home", "seed": campaign_seed, "opts": {}})


func active_sim() -> Simulation:
	return maps[active]["sim"]


func home_sim() -> Simulation:
	return maps[0]["sim"]


## Adds an outpost map (called by W4 Expedition when the party arrives). Returns its id.
func add_outpost(biome: String, crew: Array, supplies: Dictionary) -> int:
	var k := maps.size()
	var s := outpost_seed(campaign_seed, k)
	var o := {"map_w": int(cfg["map_size"]), "map_h": int(cfg["map_size"]), "biome": biome,
		"crew": crew.duplicate(true), "supplies": supplies.duplicate(true), "no_refining": true}
	var sim := Simulation.new(s, _bus_factory.call(), defs, o)
	sim.start_new_game()
	maps.append({"id": k, "biome": biome, "sim": sim, "kind": "outpost", "seed": s, "opts": o})
	var bres: Dictionary = defs.biomes.get(biome, {}).get("resources", {})
	var keys: Array = bres.keys()
	keys.sort()
	var led := Autopilot.new_ledger(biome, s, cfg, str(keys[0]) if not keys.is_empty() else "essence_ore")
	led["supplies"] = supplies.duplicate(true)
	led["miners"] = crew.size()
	ledgers[k] = led
	return k


func step() -> void:
	tick += 1
	active_sim().step()
	if tick % _ticks_per_day == 0:
		for m: Dictionary in maps:
			if m["kind"] == "outpost" and int(m["id"]) != active:
				_autopilot_day(int(m["id"]))
	_process_arrivals()


func _autopilot_day(id: int) -> void:
	var led: Dictionary = ledgers[id]
	for ev: String in Autopilot.advance_day(led, defs, cfg, _ticks_per_day):
		log.append([tick, "outpost_" + ev, [id]])
		if ev == "lost":
			_charge_collateral(id)


func _charge_collateral(id: int) -> void:
	var n := int(ledgers[id]["miners"]) * int(cfg["collateral"])
	home_debt_charged += n
	var bus: Object = home_sim().bus
	if bus != null and bus.has_signal("expedition_loss"):  # W5 declares the signal
		bus.emit_signal("expedition_loss", id, n)


## W4 hook: crates in flight are delivered by sling.gd when that file exists.
func _process_arrivals() -> void:
	if in_flight.is_empty():
		return
	if ResourceLoader.exists("res://sim/campaign/sling.gd"):
		var sl: Script = load("res://sim/campaign/sling.gd")
		if sl.has_method("process_arrivals"):
			sl.call("process_arrivals", self)


func switch_map(id: int) -> bool:
	if id < 0 or id >= maps.size() or bool(ledgers.get(id, {}).get("lost", false)):
		return false
	log.append([tick, "switch_map", [id]])
	if id == active:
		return true
	_snapshot_out(active)
	active = id
	_flush_in(id)
	var bus: Object = active_sim().bus
	if bus != null and bus.has_signal("map_switched"):  # W5 declares the signal
		bus.emit_signal("map_switched", id)
	return true


func _snapshot_out(id: int) -> void:
	if not ledgers.has(id):
		return
	var alive := 0
	for c in maps[id]["sim"].colonists.list:
		if c.alive:
			alive += 1
	ledgers[id]["miners"] = alive


func _flush_in(id: int) -> void:
	if not ledgers.has(id):
		return
	var led: Dictionary = ledgers[id]
	var sim: Simulation = maps[id]["sim"]
	if not sim.has_method("receive_cargo"):  # W2 hook: cargo stays in the ledger until it exists
		return
	for key: String in ["buffer", "inbox"]:
		if not led[key].is_empty():
			sim.call("receive_cargo", led[key].duplicate(), int(cfg["flush_radius"]))
			led[key] = {}


func map_info(id: int) -> Dictionary:
	if id < 0 or id >= maps.size():
		return {}
	var m: Dictionary = maps[id]
	return {"id": id, "biome": m["biome"], "kind": m["kind"], "seed": m["seed"], "active": id == active,
		"ledger": ledgers.get(id, {}).duplicate(true)}


func state_hash() -> int:
	var parts: Array = [campaign_seed, tick, active, log, ledgers, in_flight]
	for m: Dictionary in maps:
		parts.append([m["id"], SaveGame.state_hash(m["sim"])])
	return var_to_str(parts).hash()


func dispose() -> void:
	for m: Dictionary in maps:
		m["sim"].dispose()


# W4 hooks (stubs): Expedition/Sling own the real implementations.
func send_expedition(_biome: String, _ids: Array, _supplies: Dictionary) -> bool:
	return false


func recall(_id: int) -> bool:
	return false


func sling_send(_id: int, _items: Dictionary) -> bool:
	return false
