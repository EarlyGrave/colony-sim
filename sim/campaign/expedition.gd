class_name Expedition
extends RefCounted
## Expedition parties (home -> outpost, outpost -> home). Static helpers that act on a
## Campaign through its plain fields (W3 owns Campaign; this file never extends it):
##   c.maps: Array[{id, biome, sim, kind}]   c.tick   c.active   c.campaign_seed
##   c.in_flight: Array (shared with sling crates, tagged by "kind")
##   c.ledgers: Dictionary (map id -> {inbox, buffer, lost, ...})
##   c.defs: Defs      c.bus_factory: Callable -> bus
## Campaign.send_expedition / recall call `Expedition.send` / `Expedition.recall` (after logging
## the campaign command) and Campaign.step calls `Expedition.tick(self)` after `tick += 1`.
## Numbers live in data/expedition.json (W3); FALLBACK only covers a missing key.

const FALLBACK := {"travel_ticks": 600, "collateral": 50, "map_w": 96, "map_h": 96, "deliver_radius": 4}
const TECH := "expeditions"


static func cfg(_c: Object) -> Dictionary:
	var out: Dictionary = FALLBACK.duplicate()
	var path := "res://data/expedition.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for k: String in parsed:
				out[k] = parsed[k]
	return out


static func home_sim(c: Object) -> Simulation:
	for m: Dictionary in c.maps:
		if int(m["id"]) == 0:
			return m["sim"]
	return null


static func map_entry(c: Object, id: int) -> Dictionary:
	for m: Dictionary in c.maps:
		if int(m["id"]) == id:
			return m
	return {}


## Ledger of a map, created on demand (accepts int or string keys).
static func ledger(c: Object, id: int) -> Dictionary:
	var key: Variant = id
	if not c.ledgers.has(id) and c.ledgers.has(str(id)):
		key = str(id)
	if not c.ledgers.has(key):
		c.ledgers[key] = {}
	var l: Dictionary = c.ledgers[key]
	if not l.has("inbox"):
		l["inbox"] = {}
	if not l.has("buffer"):
		l["buffer"] = {}
	return l


static func add_items(dst: Dictionary, items: Dictionary) -> void:
	var keys: Array = items.keys()
	keys.sort()
	for k: String in keys:
		dst[k] = int(dst.get(k, 0)) + int(items[k])


## Campaign-wide counters (collateral debt charged so far), stored in c.ledgers["campaign"].
static func campaign_ledger(c: Object) -> Dictionary:
	if not c.ledgers.has("campaign"):
		c.ledgers["campaign"] = {"collateral_debt": 0}
	return c.ledgers["campaign"]


static func _bus_emit(sim: Simulation, sig: String, args: Array) -> void:
	if sim != null and sim.bus != null and sim.bus.has_signal(sig):
		sim.bus.callv("emit_signal", [sig] + args)


static func next_map_id(c: Object) -> int:
	var n := 0
	for m: Dictionary in c.maps:
		n = maxi(n, int(m["id"]))
	for f: Dictionary in c.in_flight:
		if f.has("map_id"):
			n = maxi(n, int(f["map_id"]))
	return n + 1


## Sends colonists `ids` + `supplies` from home. False (no state change) when the tech is missing,
## the biome is unknown, nothing is sent, or the home sim refuses `dispatch_party`.
static func send(c: Object, biome_id: String, ids: Array, supplies: Dictionary) -> bool:
	var home := home_sim(c)
	if home == null or ids.is_empty() or not home.research.is_done(TECH):  # strict: ignores the gating switch
		return false
	if not home.has_method("dispatch_party"):  # W2 hook
		return false
	var biomes: Dictionary = c.defs.biomes
	if not biomes.is_empty() and not biomes.has(biome_id):
		return false
	var res: Dictionary = home.dispatch_party(ids, supplies)
	if res.is_empty() or not bool(res.get("ok", true)):
		return false
	var id := next_map_id(c)
	c.in_flight.append({"kind": "party", "map_id": id, "biome": biome_id,
		"crew": res.get("crew", []), "supplies": supplies.duplicate(),
		"arrive": int(c.tick) + int(cfg(c)["travel_ticks"])})
	_bus_emit(home, "expedition_sent", [id])
	return true


## Pulls an unattended outpost back: map is removed, survivors + buffer travel home.
static func recall(c: Object, map_id: int) -> bool:
	var m := map_entry(c, map_id)
	if m.is_empty() or str(m.get("kind", "")) != "outpost" or int(c.active) == map_id:
		return false
	var sim: Simulation = m["sim"]
	var items: Dictionary = {}
	var led := ledger(c, map_id)
	add_items(items, led["buffer"])
	add_items(items, led["inbox"])
	var crew: Array = []
	if not bool(led.get("lost", false)):
		for col in sim.colonists.list:
			if col.alive:
				crew.append({"name": col.display_name})
	c.in_flight.append({"kind": "return", "from": map_id, "crew": crew, "items": items,
		"arrive": int(c.tick) + int(cfg(c)["travel_ticks"])})
	c.maps.erase(m)
	c.ledgers.erase(map_id)
	c.ledgers.erase(str(map_id))
	sim.dispose()
	return true


## Call once per Campaign.step after `tick += 1`.
static func tick(c: Object) -> void:
	var due: Array = []
	for f: Dictionary in c.in_flight:
		var k := str(f.get("kind", "crate"))
		if (k == "party" or k == "return") and int(f["arrive"]) <= int(c.tick):
			due.append(f)
	for f: Dictionary in due:
		c.in_flight.erase(f)
		if str(f["kind"]) == "party":
			_arrive_party(c, f)
		else:
			_arrive_return(c, f)
	_charge_losses(c)


static func _arrive_party(c: Object, f: Dictionary) -> void:
	var id := int(f["map_id"])
	var conf := cfg(c)
	var seed_k := int(c.campaign_seed) * 1000003 + id * 7919
	var opts := {"map_w": int(conf["map_w"]), "map_h": int(conf["map_h"]), "biome": f["biome"],
		"crew": f["crew"], "supplies": f["supplies"], "no_refining": true}
	var sim := Simulation.new(seed_k, c.bus_factory.call(), c.defs, opts)
	sim.start_new_game()
	c.maps.append({"id": id, "biome": f["biome"], "sim": sim, "kind": "outpost", "seed": seed_k,
		"opts": opts, "crew_n": (f["crew"] as Array).size(), "dead_charged": 0, "sling_ready": 0})
	ledger(c, id)
	_bus_emit(home_sim(c), "expedition_arrived", [id])


static func _arrive_return(c: Object, f: Dictionary) -> void:
	var home := home_sim(c)
	var items: Dictionary = f["items"]
	if home != null and int(c.active) == 0 and home.has_method("receive_cargo") and not items.is_empty():
		home.receive_cargo(items, int(cfg(c)["deliver_radius"]))
	else:
		add_items(ledger(c, 0)["inbox"], items)
	var crew: Array = f["crew"]
	if not crew.is_empty():
		if home != null and int(c.active) == 0 and home.has_method("receive_party"):
			home.receive_party(crew)
		else:
			var l := ledger(c, 0)
			var back: Array = l.get("returning_crew", [])
			back.append_array(crew)
			l["returning_crew"] = back


## Each dead crew member (or the whole crew of a lost outpost) adds `collateral` to home debt, once.
static func _charge_losses(c: Object) -> void:
	for m: Dictionary in c.maps:
		if str(m.get("kind", "")) != "outpost":
			continue
		var n := int(m.get("crew_n", 0))
		var dead := 0
		if bool(ledger(c, int(m["id"])).get("lost", false)):
			dead = n
		else:
			var alive := 0
			for col in (m["sim"] as Simulation).colonists.list:
				if col.alive:
					alive += 1
			dead = clampi(n - alive, 0, n)
		var delta := dead - int(m.get("dead_charged", 0))
		if delta <= 0:
			continue
		m["dead_charged"] = dead
		var debt := delta * int(cfg(c)["collateral"])
		var cl := campaign_ledger(c)
		cl["collateral_debt"] = int(cl["collateral_debt"]) + debt
		var home := home_sim(c)
		if home != null and home.has_method("charge_debt"):
			home.charge_debt(debt)
		_bus_emit(home, "expedition_loss", [int(m["id"]), debt])
