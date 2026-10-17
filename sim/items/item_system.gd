class_name ItemSystem
extends RefCounted
## Items lying on the map (one stack per cell) and storage zones.
## Items carried by colonists or held in buildings live there; `count_world`
## sums every place an item can be, for the conservation invariant.

var sim: Simulation
## Vector2i -> {"item": String, "count": int}
var stacks: Dictionary = {}
## zone_id -> {Vector2i: true}, insertion-ordered for determinism.
var zone_cells: Dictionary = {}


func _init(p_sim: Simulation) -> void:
	sim = p_sim


# --- Stacks -----------------------------------------------------------------

func get_stack(c: Vector2i) -> Dictionary:
	return stacks.get(c, {})


func item_at(c: Vector2i) -> String:
	return stacks[c]["item"] if stacks.has(c) else ""


func count_at(c: Vector2i) -> int:
	return int(stacks[c]["count"]) if stacks.has(c) else 0


## How many of `item_id` can still be put on cell `c`.
func space_for(c: Vector2i, item_id: String) -> int:
	if not sim.cell_free_for_items(c):
		return 0
	if not stacks.has(c):
		return sim.defs.item_stack(item_id)
	if stacks[c]["item"] != item_id:
		return 0
	return sim.defs.item_stack(item_id) - int(stacks[c]["count"])


## Adds up to `n` items on one cell. Returns how many were added.
func add_at(c: Vector2i, item_id: String, n: int) -> int:
	var k := mini(n, space_for(c, item_id))
	if k <= 0:
		return 0
	if stacks.has(c):
		stacks[c]["count"] += k
	else:
		stacks[c] = {"item": item_id, "count": k}
	return k


## Puts all `n` items on the map near `c`, spilling to the nearest free cells.
## Returns the number that could not be placed (0 unless the map is full).
func drop(c: Vector2i, item_id: String, n: int) -> int:
	var left := n
	left -= add_at(c, item_id, left)
	if left <= 0:
		return 0
	var seen := {c: true}
	var queue: Array[Vector2i] = [c]
	var head := 0
	while head < queue.size() and left > 0:
		var cur := queue[head]
		head += 1
		for d in MapGrid.NEIGHBORS_4:
			var nb := cur + d
			if seen.has(nb) or not sim.map.in_bounds(nb):
				continue
			seen[nb] = true
			if sim.map.is_passable(nb):
				left -= add_at(nb, item_id, left)
				queue.append(nb)
	if left > 0:
		# No room anywhere reachable: the items are lost, but accounted for.
		sim.ledger.record_consumed(item_id, left, "lost")
	return left


## Removes up to `n` items from a cell. Returns how many were taken.
func take_at(c: Vector2i, n: int) -> int:
	if not stacks.has(c):
		return 0
	var k := mini(n, int(stacks[c]["count"]))
	stacks[c]["count"] -= k
	if stacks[c]["count"] <= 0:
		stacks.erase(c)
	return k


## True if the stack on `c` sits in a zone that accepts it.
func is_stored(c: Vector2i) -> bool:
	if not stacks.has(c):
		return false
	return sim.defs.zone_accepts(sim.map.get_zone(c), stacks[c]["item"])


func count_on_ground(item_id: String) -> int:
	var s := 0
	for c in stacks:
		if stacks[c]["item"] == item_id:
			s += int(stacks[c]["count"])
	return s


func count_stored(item_id: String) -> int:
	var s := 0
	for c in stacks:
		if stacks[c]["item"] == item_id and is_stored(c):
			s += int(stacks[c]["count"])
	return s


## Every unit of `item_id` that exists: ground + carried + inside buildings.
func count_world(item_id: String) -> int:
	var s := count_on_ground(item_id)
	for col in sim.colonists.list:
		if col.carry_item == item_id:
			s += col.carry_count
	if sim.buildings:
		s += sim.buildings.count_item(item_id)
	return s


## Removes `n` stored items (nearest to `near` first). All-or-nothing.
func consume_stored(item_id: String, n: int, near: Vector2i) -> bool:
	if count_stored(item_id) < n:
		return false
	var cells: Array[Vector2i] = []
	for c in stacks:
		if stacks[c]["item"] == item_id and is_stored(c):
			cells.append(c)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(near) < b.distance_squared_to(near))
	var left := n
	for c in cells:
		left -= take_at(c, left)
		if left <= 0:
			break
	return true


# --- Zones ------------------------------------------------------------------

func set_zone(c: Vector2i, zone_id: String) -> void:
	var old := sim.map.get_zone(c)
	if old == zone_id:
		return
	if old != "":
		zone_cells[old].erase(c)
	if zone_id != "":
		if not zone_cells.has(zone_id):
			zone_cells[zone_id] = {}
		zone_cells[zone_id][c] = true
	sim.map.set_zone(c, zone_id)


## Nearest zone cell that accepts `item_id` and has room, skipping cells
## for which `is_blocked(cell)` is true. Vector2i(-1, -1) if none.
func find_storage_cell(item_id: String, near: Vector2i, is_blocked: Callable) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for zone_id in zone_cells:
		if not sim.defs.zone_accepts(zone_id, item_id):
			continue
		for c: Vector2i in zone_cells[zone_id]:
			var d := c.distance_squared_to(near)
			if d >= best_d or space_for(c, item_id) <= 0 or is_blocked.call(c):
				continue
			if not sim.pathfinder.reachable(near, c):
				continue
			best = c
			best_d = d
	return best
