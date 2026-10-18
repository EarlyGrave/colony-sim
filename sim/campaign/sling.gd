class_name Sling
extends RefCounted
## Sling cargo: an outpost building `sling` (data/buildings.json: capacity, cooldown, travel,
## max_in_flight, deliver_radius) shoots crates to the home map. Crates live in `c.in_flight`
## as {"kind":"crate","from":id,"to":0,"items":{item:n},"arrive":tick}.
## Campaign.sling_send calls `Sling.send`; Campaign.step calls `Sling.tick(self)` after `tick += 1`.

const DEF_ID := "sling"


static func sling_def(c: Object) -> Dictionary:
	return (c.defs.buildings as Dictionary).get(DEF_ID, {})


static func _has_working_sling(sim: Simulation) -> bool:
	for b in sim.buildings.list:
		if b.def_id == DEF_ID and not b.broken:
			return true
	return false


static func in_flight_from(c: Object, map_id: int) -> int:
	var n := 0
	for f: Dictionary in c.in_flight:
		if str(f.get("kind", "crate")) == "crate" and int(f["from"]) == map_id:
			n += 1
	return n


## Queues a crate from outpost `map_id` to home. False (no state change) on: no outpost / no working
## sling / over capacity / cooling down / too many in flight / items not owned (sim refuses).
static func send(c: Object, map_id: int, items: Dictionary) -> bool:
	var m := Expedition.map_entry(c, map_id)
	var def := sling_def(c)
	if m.is_empty() or def.is_empty() or str(m.get("kind", "")) != "outpost":
		return false
	var total := 0
	for k: String in items:
		if int(items[k]) < 0:
			return false
		total += int(items[k])
	if total <= 0 or total > int(def["capacity"]):
		return false
	if int(c.tick) < int(m.get("sling_ready", 0)) or in_flight_from(c, map_id) >= int(def["max_in_flight"]):
		return false
	var sim: Simulation = m["sim"]
	if not _has_working_sling(sim) or not sim.has_method("dispatch_party"):
		return false
	var res: Dictionary = sim.dispatch_party([], items)  # removes the stacks; recorded in the outpost log
	if res.is_empty() or not bool(res.get("ok", true)):
		return false
	c.in_flight.append({"kind": "crate", "from": map_id, "to": 0, "items": items.duplicate(),
		"arrive": int(c.tick) + int(def["travel"])})
	m["sling_ready"] = int(c.tick) + int(def["cooldown"])
	return true


## Delivers crates due at `c.tick` (in_flight order). Active target: sim command `receive_cargo`;
## otherwise the items wait in the target ledger inbox (flushed by switch_map).
static func tick(c: Object) -> void:
	var due: Array = []
	for f: Dictionary in c.in_flight:
		if str(f.get("kind", "crate")) == "crate" and int(f["arrive"]) <= int(c.tick):
			due.append(f)
	if due.is_empty():
		return
	var radius := int(sling_def(c).get("deliver_radius", 4))
	for f: Dictionary in due:
		c.in_flight.erase(f)
		var to := int(f["to"])
		var m := Expedition.map_entry(c, to)
		if m.is_empty():
			continue
		var sim: Simulation = m["sim"]
		var n := 0
		for k: String in f["items"]:
			n += int(f["items"][k])
		if int(c.active) == to and sim.has_method("receive_cargo"):
			sim.receive_cargo(f["items"], radius)
		else:
			Expedition.add_items(Expedition.ledger(c, to)["inbox"], f["items"])
		if sim.bus != null and sim.bus.has_signal("cargo_arrived"):
			sim.bus.emit_signal("cargo_arrived", to, n)
