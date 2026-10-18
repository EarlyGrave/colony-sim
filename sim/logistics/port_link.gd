class_name PortLink
extends RefCounted
## Connects building ports to belts. Called once per tick by LogisticsSystem
## (before belts step), buildings in id order, ports in def order: deterministic.
##
## Port geometry: def.ports[i] = {dx, dy, dir, kind}. The belt cell is
## `building.cell + (dx, dy)` (adjacent to the footprint). Per tick each port moves
## at most one item.
##   out port: belt cell must be empty, have a belt, and not point back into the
##             building (head-on); one item is taken from the building and inserted.
##   in port:  belt cell must hold a READY item and its belt must point into the
##             building; the item is moved in only if the building accepts it.
##
## Port-buffer interface (duck-typed, all optional). A machine (A2a) may define on
## its Building/Machine class any of these; PortLink falls back to the defaults below:
##   port_accepts(item: String) -> bool   can one unit enter via an in port now?
##   port_accept(item: String) -> bool    store one unit (true on success)
##   port_peek() -> String                item name offered at an out port ("" none)
##   port_take(item: String) -> bool      remove one unit of that item
## Defaults: processors use Building.input_space/add_input for input and
## Building.output (first item name in sorted order) for output. Port buildings
## (def.port_building): storage_in belt -> `output` buffer (colonists haul it to a
## zone); storage_out `input` buffer (colonists haul into it) -> belt.
## Buffers hold at most def.buffer_capacity / output_capacity items in total.

const DIRS: Array[Vector2i] = BeltGrid.DIRS


static func tick(sim: Simulation) -> void:
	if sim.buildings == null or sim.logistics == null:
		return
	for b: Building in sim.buildings.list:
		if b.destroyed or b.broken or not b.def.has("ports"):
			continue
		for p: Dictionary in b.def["ports"]:
			var cell := b.cell + Vector2i(int(p["dx"]), int(p["dy"]))
			if str(p["kind"]) == "out":
				_push(sim, b, cell)
			else:
				_pull(sim, b, cell)


static func _push(sim: Simulation, b: Building, cell: Vector2i) -> void:
	var belts := sim.logistics.belts
	var d := belts.belt_dir(cell)
	if d < 0 or belts.item_at(cell) >= 0 or b.contains(cell + DIRS[d]):
		return
	var item := peek(b)
	if item == "" or not sim.logistics.insert_item(cell, item):
		return
	take(b, item)


static func _pull(sim: Simulation, b: Building, cell: Vector2i) -> void:
	var belts := sim.logistics.belts
	var d := belts.belt_dir(cell)
	if d < 0 or not b.contains(cell + DIRS[d]):
		return
	var id := belts.peek_ready(cell)
	if id < 0:
		return
	var item := sim.logistics.item_name(id)
	if not accepts(b, item):
		return
	sim.logistics.take_ready_item(cell)
	accept(b, item)


# --- Buffer interface with defaults -----------------------------------------

static func _total(d: Dictionary) -> int:
	var s := 0
	for k in d:
		s += int(d[k])
	return s


static func accepts(b: Building, item: String) -> bool:
	if b.has_method("port_accepts"):
		return b.port_accepts(item)
	if b.def.get("port_building", false):
		return _total(b.output) < int(b.def.get("buffer_capacity", 0))
	return b.input_space(item) > 0


static func accept(b: Building, item: String) -> bool:
	if b.has_method("port_accept"):
		return b.port_accept(item)
	if b.def.get("port_building", false):
		b.output[item] = int(b.output.get(item, 0)) + 1
		return true
	return b.add_input(item, 1) == 1


static func peek(b: Building) -> String:
	if b.has_method("port_peek"):
		return b.port_peek()
	var buf: Dictionary = b.input if b.def.get("port_building", false) else b.output
	var keys: Array = buf.keys()
	keys.sort()
	for k in keys:
		if int(buf[k]) > 0:
			return str(k)
	return ""


static func take(b: Building, item: String) -> bool:
	if b.has_method("port_take"):
		return b.port_take(item)
	if b.def.get("port_building", false):
		b.input[item] = int(b.input[item]) - 1
		if int(b.input[item]) <= 0:
			b.input.erase(item)
		return true
	return b.take_output(item, 1) == 1


## Colonist-side space of a port building's hand-fed buffer (storage_out). Hooked
## from Building.input_space. storage_in (no out port) takes nothing by hand.
static func manual_input_space(b: Building) -> int:
	for p: Dictionary in b.def.get("ports", []):
		if str(p["kind"]) == "out":
			return maxi(0, int(b.def.get("buffer_capacity", 0)) - _total(b.input))
	return 0
