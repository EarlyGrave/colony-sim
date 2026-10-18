class_name Militia
extends RefCounted
## C5: on alarm, idle inmates outside any squad rally to the nearest squad banner and fight.
## Built on the plain draft/order commands (deterministic, no rng). Numbers: data/roles.json "militia".
## Squads come from C1 (`sim.squads.list`, each with `members`, `hold`); with no squads this is a no-op.

const ROLES_PATH := "res://data/roles.json"

var sim: Simulation
var cfg: Dictionary
## Colonist ids currently drafted by the militia.
var members: Array[int] = []
## Ids that fled this alarm (not re-drafted until the alarm ends).
var spent: Array[int] = []


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = load_cfg()


static func load_cfg() -> Dictionary:
	var f := FileAccess.open(ROLES_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return (d as Dictionary).get("militia", {}) if d is Dictionary else {}


func active() -> bool:
	return not members.is_empty()


## Squad list from C1 (`sim.squads.list`); tests may plant one with set_meta("squads_override").
func squad_list() -> Array:
	var sq: Variant = sim.get_meta("squads_override") if sim.has_meta("squads_override") else sim.get("squads")
	if sq == null:
		return []
	var l: Variant = sq.get("list")
	return l if l is Array else []


func in_squad(id: int) -> bool:
	for s: Variant in squad_list():
		if id in (s.members as Array):
			return true
	return false


## Banner cell of a squad: its hold cell, else its first living member's cell.
func banner_cell(s: Variant) -> Vector2i:
	var h: Variant = s.get("hold")
	if h is Vector2i and (h as Vector2i).x >= 0:
		return h
	for id: Variant in (s.members as Array):
		var c := sim.colonists.get_by_id(int(id))
		if c != null and c.alive:
			return c.cell
	return Vector2i(-1, -1)


func nearest_banner(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for s: Variant in squad_list():
		var b := banner_cell(s)
		if b.x < 0:
			continue
		var d := Vector2(from).distance_squared_to(Vector2(b))
		if d < best_d:
			best_d = d
			best = b
	return best


func _rally_cell(banner: Vector2i, slot: int) -> Vector2i:
	var offs: Array = cfg.get("rally_offsets", [[0, 1]])
	for i in offs.size():
		var o: Array = offs[(slot + i) % offs.size()]
		var cell := banner + Vector2i(int(o[0]), int(o[1]))
		if sim.map.in_bounds(cell) and sim.map.is_passable(cell):
			return cell
	return banner


func tick() -> void:
	if cfg.is_empty():
		return
	if not sim.alarm or not bool(sim.rules.get("militia_rally", true)):
		if not members.is_empty() or not spent.is_empty():
			release_all()
		return
	if sim.tick % int(cfg["tick_period"]) != 0:
		return
	_check_members()
	if squad_list().is_empty() or members.size() >= int(cfg["max_members"]):
		return
	var min_hp := float(cfg["min_hp_fraction"])
	for c in sim.colonists.list:
		if members.size() >= int(cfg["max_members"]):
			break
		if not c.alive or c.combat == null or c.combat.drafted or c.id in spent or in_squad(c.id):
			continue
		if c.health != null and c.health.downed:
			continue
		if c.hp < c.max_hp * min_hp:
			continue
		var banner := nearest_banner(c.cell)
		if banner.x < 0:
			continue
		if sim.combat.set_drafted(c, true):
			members.append(c.id)
			sim.combat.order_move(c, _rally_cell(banner, members.size() - 1))


func _check_members() -> void:
	for id in members.duplicate():
		var c := sim.colonists.get_by_id(id)
		if c == null or not c.alive or c.combat == null or not c.combat.drafted:
			members.erase(id)  # died, or the player took over
		elif sim.combat.is_low_hp(c) or (c.health != null and c.health.downed):
			sim.combat.set_drafted(c, false)
			members.erase(id)
			spent.append(id)


func release_all() -> void:
	for id in members:
		var c := sim.colonists.get_by_id(id)
		if c != null and c.alive and c.combat != null and c.combat.drafted:
			sim.combat.set_drafted(c, false)
	members.clear()
	spent.clear()
