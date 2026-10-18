class_name SquadSystem
extends RefCounted
## Wardens of the Line: squads of up to 4 inmates with roles. Commands go through Simulation
## (form_squad / disband_squad / squad_hold / squad_focus). No rng; squads iterate by id.
## Single-inmate drafting stays available for inmates outside any squad (owner decision).

var sim: Simulation
var list: Array[Squad] = []  # ascending id
var _next_id := 1


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	sim.listen(sim.bus.colonist_died, _on_colonist_died)


func get_squad(sid: int) -> Squad:
	for s in list:
		if s.id == sid:
			return s
	return null


func squad_of(colonist_id: int) -> Squad:
	for s in list:
		if s.members.has(colonist_id):
			return s
	return null


func max_size() -> int:
	return int(sim.defs.roles["max_size"])


## Affinity score of colonist `c` for `role`: skill level + trait bonus (data weights).
func affinity(c: Colonist, role: String) -> float:
	var cfg: Dictionary = sim.defs.roles["affinity"]
	var rd: Dictionary = sim.defs.roles["roles"][role]
	var score := 0.0
	if c.skills != null:
		score = float(c.skills.level(str(rd["affinity_skill"]))) * float(cfg["skill_weight"])
	for t: String in c.bio.get("traits", []):
		var tr: Dictionary = sim.defs.traits["traits"].get(t, {})
		score += float((tr.get("role_affinity", {}) as Dictionary).get(role, 0.0)) * float(cfg["trait_weight"])
	return score


## Suggested role per id (same order). Distinct roles first (best score wins; ties: lower id, role order),
## leftovers take their best role.
func suggest_roles(ids: Array) -> Array[String]:
	var order: Array = sim.defs.roles["order"]
	var out: Array[String] = []
	out.resize(ids.size())
	var cols: Array = []
	for id in ids:
		cols.append(sim.colonists.get_by_id(int(id)))
	var free_roles: Array = order.duplicate()
	var left: Array = range(ids.size())
	while not left.is_empty() and not free_roles.is_empty():
		var best_i := -1
		var best_r := ""
		var best_s := -INF
		for i: int in left:
			if cols[i] == null:
				continue
			for r: String in free_roles:
				var sc := affinity(cols[i], r)
				if sc > best_s or (sc == best_s and int(ids[i]) < int(ids[best_i])):
					best_s = sc
					best_i = i
					best_r = r
		if best_i < 0:
			break
		out[best_i] = best_r
		left.erase(best_i)
		free_roles.erase(best_r)
	for i: int in left:
		var br: String = order[0]
		var bs := -INF
		for r: String in order:
			var sc := affinity(cols[i], r) if cols[i] != null else 0.0
			if sc > bs:
				bs = sc
				br = r
		out[i] = br
	return out


# --- Commands ---------------------------------------------------------------------

func form(ids: Array, roles: Array) -> int:
	if ids.is_empty() or ids.size() > max_size():
		return -1
	var seen := {}
	for id in ids:
		var c := sim.colonists.get_by_id(int(id))
		if c == null or not c.alive or seen.has(int(id)) or squad_of(int(id)) != null:
			return -1
		seen[int(id)] = true
	var picked: Array[String] = []
	var auto := suggest_roles(ids)
	if roles.is_empty():
		picked = auto
	else:
		if roles.size() != ids.size():
			return -1
		for i in roles.size():
			var r := str(roles[i])
			if r == "" or r == "auto":
				r = auto[i]
			if not sim.defs.roles["roles"].has(r):
				return -1
			picked.append(r)
	var s := Squad.new()
	s.id = _next_id
	_next_id += 1
	s.name = "Squad %d" % s.id
	for i in ids.size():
		var id := int(ids[i])
		var c := sim.colonists.get_by_id(id)
		s.members.append(id)
		s.role_of[id] = picked[i]
		s.weapon_before[id] = c.combat.weapon
		c.combat.weapon = str(sim.defs.roles["roles"][picked[i]]["weapon"])
		sim.combat.set_drafted(c, true)
	list.append(s)
	return s.id


func disband(sid: int) -> bool:
	var s := get_squad(sid)
	if s == null:
		return false
	for id in s.members:
		var c := sim.colonists.get_by_id(id)
		if c != null and c.alive:
			c.combat.weapon = str(s.weapon_before.get(id, c.combat.weapon))
			sim.combat.set_drafted(c, false)
	list.erase(s)
	return true


func hold(sid: int, cell: Vector2i) -> bool:
	var s := get_squad(sid)
	if s == null or not sim.map.in_bounds(cell) or not sim.map.is_passable(cell):
		return false
	s.hold = cell
	s.focus = -1
	_assign_slots(s)
	return true


func focus(sid: int, enemy_id: int) -> bool:
	var s := get_squad(sid)
	if s == null or sim.combat.enemy_by_id(enemy_id) == null:
		return false
	s.focus = enemy_id
	for id in s.members:
		if s.role_of[id] == "medic":
			continue
		var c := sim.colonists.get_by_id(id)
		if c != null:
			sim.combat.order_attack(c, enemy_id)
	return true


# --- Internals --------------------------------------------------------------------

## Each member gets the formation cell (role offset + spread for duplicate roles), moved to the nearest free reachable cell.
func _assign_slots(s: Squad) -> void:
	s.slot_cell.clear()
	var taken := {}
	var dup := {}
	var spread: Array = sim.defs.roles["slot_spread"]
	for id in s.members:
		var c := sim.colonists.get_by_id(id)
		if c == null:
			continue
		var role: String = s.role_of[id]
		var off: Array = sim.defs.roles["roles"][role]["formation_offset"]
		var k: int = dup.get(role, 0)
		dup[role] = k + 1
		var want := s.hold + Vector2i(int(off[0]) + k * int(spread[0]), int(off[1]) + k * int(spread[1]))
		var cell := _free_near(want, c, taken)
		taken[cell] = true
		s.slot_cell[id] = cell
		sim.combat.order_move(c, cell)


func _free_near(want: Vector2i, c: Colonist, taken: Dictionary) -> Vector2i:
	var r_max := int(sim.defs.roles["hold_search_radius"])
	for r in range(0, r_max + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cand := want + Vector2i(dx, dy)
				if sim.map.in_bounds(cand) and sim.map.is_passable(cand) and not taken.has(cand) and sim.pathfinder.reachable(c.cell, cand):
					return cand
	return c.cell


## Ends focus once the target is gone and sends members back to their slots.
func tick() -> void:
	for s in list:
		if s.focus >= 0 and sim.combat.enemy_by_id(s.focus) == null:
			s.focus = -1
			if s.hold.x >= 0:
				for id in s.members:
					var c := sim.colonists.get_by_id(id)
					if c != null and s.slot_cell.has(id):
						sim.combat.order_move(c, s.slot_cell[id])


func _on_colonist_died(id: int) -> void:
	var s := squad_of(id)
	if s == null:
		return
	s.members.erase(id)
	s.role_of.erase(id)
	s.weapon_before.erase(id)
	s.slot_cell.erase(id)
	if s.members.is_empty():
		list.erase(s)


func state_parts() -> Array:
	var out: Array = []
	for s in list:
		out.append(s.state_part())
	return out
