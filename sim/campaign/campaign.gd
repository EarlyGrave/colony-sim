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
var bus_factory: Callable
var _ticks_per_day := 600


func _init(p_seed: int, p_bus_factory: Callable, p_defs: Defs = null, p_opts := {}) -> void:
	campaign_seed = p_seed
	bus_factory = p_bus_factory
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
	var sim := Simulation.new(campaign_seed, bus_factory.call(), defs, opts.get("home_opts", {}))
	sim.start_new_game()
	maps.append({"id": 0, "biome": "start", "sim": sim, "kind": "home", "seed": campaign_seed, "opts": {}})


func entry(id: int) -> Dictionary:
	return Expedition.map_entry(self, id)


func active_sim() -> Simulation:
	return entry(active)["sim"]


func home_sim() -> Simulation:
	return entry(0)["sim"]


## Adds an outpost map (called by Expedition when the party arrives). `id` < 0 = next free id.
## Returns the id. Map ids are stable (a recalled outpost leaves a gap), never list indices.
func add_outpost(biome: String, crew: Array, supplies: Dictionary, id := -1) -> int:
	var k := id if id >= 0 else Expedition.next_map_id(self)
	var s := outpost_seed(campaign_seed, k)
	var size := int(cfg["map_size"])
	var o := {"map_w": size, "map_h": size, "biome": biome,
		"crew": crew.duplicate(true), "supplies": supplies.duplicate(true), "no_refining": true}
	var sim := Simulation.new(s, bus_factory.call(), defs, o)
	sim.start_new_game()
	maps.append({"id": k, "biome": biome, "sim": sim, "kind": "outpost", "seed": s, "opts": o,
		"crew_n": crew.size(), "dead_charged": 0, "sling_ready": 0})
	var bres: Dictionary = defs.biomes.get(biome, {}).get("resources", {})
	var keys: Array = bres.keys()
	keys.sort()
	var led := Autopilot.new_ledger(biome, s, cfg, str(keys[0]) if not keys.is_empty() else "essence_ore")
	led["supplies"] = supplies.duplicate(true)
	led["miners"] = crew.size()
	ledgers[k] = led
	return k


## One campaign tick: active map steps for real, outposts advance per day, then travel/cargo arrivals.
func step() -> void:
	tick += 1
	active_sim().step()
	if tick % _ticks_per_day == 0:
		for m: Dictionary in maps:
			if m["kind"] == "outpost" and int(m["id"]) != active:
				_autopilot_day(int(m["id"]))
	Expedition.tick(self)
	Sling.tick(self)
	if tick % _ticks_per_day == 0:  # region K2
		_k2_day()  # region K2


func _autopilot_day(id: int) -> void:
	for ev: String in Autopilot.advance_day(ledgers[id], defs, cfg, _ticks_per_day):
		log.append([tick, "outpost_" + ev, [id]])  # a lost outpost is charged by Expedition.tick


# --- Commands (logged, then delegated to the W4 helpers) --------------------------------

func send_expedition(biome: String, ids: Array, supplies: Dictionary) -> bool:
	var ok := Expedition.send(self, biome, ids, supplies)
	if ok:
		log.append([tick, "send_expedition", [biome, ids.duplicate(), supplies.duplicate()]])
	return ok


func recall(id: int) -> bool:
	var ok := Expedition.recall(self, id)
	if ok:
		log.append([tick, "recall", [id]])
	return ok


## Fires a crate from the ACTIVE outpost (its sling, its stored items) to `target` (home = 0).
func sling_send(target: int, items: Dictionary) -> bool:
	if target != 0 or active == 0:
		return false
	var ok := Sling.send(self, active, items)
	if ok:
		log.append([tick, "sling_send", [target, items.duplicate()]])
	return ok


func switch_map(id: int) -> bool:
	if entry(id).is_empty() or bool(ledgers.get(id, {}).get("lost", false)):
		return false
	log.append([tick, "switch_map", [id]])
	if id == active:
		return true
	_snapshot_out(active)
	active = id
	_flush_in(id)
	var bus: Object = active_sim().bus
	if bus != null and bus.has_signal("map_switched"):
		bus.emit_signal("map_switched", id)
	return true


func _snapshot_out(id: int) -> void:
	if not ledgers.has(id):
		return
	var alive := 0
	for c in entry(id)["sim"].colonists.list:
		if c.alive:
			alive += 1
	ledgers[id]["miners"] = alive


func _flush_in(id: int) -> void:
	var led: Dictionary = Expedition.ledger(self, id)
	var sim: Simulation = entry(id)["sim"]
	for key: String in ["buffer", "inbox"]:
		if not led[key].is_empty():
			sim.receive_cargo(led[key].duplicate(), int(cfg["flush_radius"]))
			led[key] = {}
	var back: Array = led.get("returning_crew", [])
	if not back.is_empty():
		sim.receive_party(back.duplicate(true))
		led["returning_crew"] = []


func map_info(id: int) -> Dictionary:
	var m := entry(id)
	if m.is_empty():
		return {}
	var led: Dictionary = ledgers.get(id, {})
	return {"id": id, "biome": m["biome"], "kind": m["kind"], "seed": m["seed"], "active": id == active,
		"lost": bool(led.get("lost", false)), "alarm": _alarm(m, led), "ledger": led.duplicate(true)}


## Unattended-map warning for the switcher: alarm on, or the outpost has been damaged by raids.
func _alarm(m: Dictionary, led: Dictionary) -> bool:
	return bool(m["sim"].alarm) or (m["kind"] == "outpost" and int(led.get("integrity", 100)) < int(cfg["integrity_max"]))


## Canonical form: dictionary keys sorted recursively, so a save/load round trip (JSON sorts keys) hashes equal.
static func _canon(v: Variant) -> Variant:
	if v is Dictionary:
		var keys: Array = (v as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var out: Array = []
		for k: Variant in keys:
			out.append([str(k), _canon(v[k])])
		return out
	if v is Array:
		var out: Array = []
		for x: Variant in v:
			out.append(_canon(x))
		return out
	return v


func state_hash() -> int:
	var parts: Array = [campaign_seed, tick, active, _canon(log), _canon(ledgers), _canon(in_flight)]
	for m: Dictionary in maps:
		parts.append([m["id"], SaveGame.state_hash(m["sim"]), m.get("sling_ready", 0), m.get("dead_charged", 0)])
	return var_to_str(parts).hash()


func dispose() -> void:
	for m: Dictionary in maps:
		m["sim"].dispose()


# region K2: outposts feed the home Parole Review and act as audit decoys.
func _k2_day() -> void:
	var held := 0
	for m: Dictionary in maps:
		if str(m["kind"]) == "outpost" and not bool(ledgers.get(int(m["id"]), {}).get("lost", false)):
			held += 1
	home_sim().milestones.k2_note_day(held)
# endregion
