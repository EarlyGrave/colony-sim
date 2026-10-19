class_name FightEscape
extends RefCounted
## EN3: Fight ending (Uplink Array + Collector assault) and Escape ending (bandit fee, extraction point).
## Commands only through Simulation. Numbers: data/endings.json "fight"/"escape". Deterministic, no rng.
## Winning goes through sim.endings.mark_won(). Replay-based saves re-run the commands.

var sim: Simulation
# Fight
var assault_step := -1  # -1 = not started, 0..n-1 = raids launched
var assault_start := 0
var assault_done := false
var assault_failed := 0
# Escape
var contacted := false
var paid := false
var counting := false
var t_left := 0
var extract_failed := 0
var extract_cell := Vector2i(-1, -1)
var extracted := 0  # colonists that left (legacy)


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func _fc() -> Dictionary:
	return sim.defs.endings.get("fight", {})


func _ec() -> Dictionary:
	return sim.defs.endings.get("escape", {})


# region fight
func uplink() -> Building:
	var id := str(_fc().get("building", "uplink_array"))
	for b in sim.buildings.list:
		if b.def_id == id and not b.destroyed:
			return b
	return null


func uplink_ready() -> bool:
	var u := uplink()
	return u != null and not u.broken and sim.power.factor_for(u) >= float(_fc().get("min_power_factor", 0.5))


func assault_active() -> bool:
	return assault_step >= 0 and not assault_done


func start_assault() -> bool:
	if sim.path() != "fight" or assault_active() or assault_done or not uplink_ready():
		return false
	sim.quests.set_flag("ponr_fight")
	assault_step = 0
	assault_start = sim.tick
	_launch_raid(0)
	return true


func _raids() -> Array:
	return _fc().get("raids", [])


func _launch_raid(i: int) -> void:
	var r: Dictionary = _raids()[i]
	sim.threats.start_wave(float(r.get("mult", 1.0)))


func _fight_tick() -> void:
	if not assault_active():
		return
	if uplink() == null:
		assault_step = -1
		assault_failed += 1
		sim.bus.letter_received.emit("Uplink lost", str(_fc().get("lines", {}).get("lost", "")))
		return
	var raids := _raids()
	var nxt := assault_step + 1
	if nxt < raids.size():
		var at := assault_start + roundi(float((raids[nxt] as Dictionary).get("day", 0.0)) * sim.ticks_per_day)
		if sim.tick >= at:
			assault_step = nxt
			_launch_raid(nxt)
		return
	if not sim.threats.wave_active and sim.threats.enemies.is_empty():
		assault_done = true
		sim.bus.letter_received.emit("Collector destroyed", str(_fc().get("lines", {}).get("won", "")))
		sim.endings.mark_won("fight")
# endregion


# region escape
func can_contact() -> String:
	if sim.path() != "escape":
		return "no_escape_path"
	if contacted:
		return "done"
	if sim.contraband.sales < int(_ec().get("contact_sales", 3)):
		return "need_sales"
	return ""


func contact_bandits() -> bool:
	if can_contact() != "":
		return false
	contacted = true
	sim.quests.set_flag("ponr_escape")
	extract_cell = _pick_extract_cell()
	return true


func bandit_fee() -> int:
	return int(_ec().get("bandit_fee", 60))


func pay_fee() -> bool:
	if not contacted or paid or sim.contraband.escape_credit < bandit_fee():
		return false
	sim.contraband.escape_credit -= bandit_fee()
	paid = true
	return true


func start_extraction() -> bool:
	if not paid or counting or sim.endings.won("escape"):
		return false
	counting = true
	t_left = roundi(float(_ec().get("countdown_days", 1.0)) * sim.ticks_per_day)
	sim.threats.start_wave(float(_ec().get("pursuit_mult", 1.5)))
	return true


## Fixed spot: first walkable cell scanning outward from the map's south-east corner (deterministic).
func _pick_extract_cell() -> Vector2i:
	var g := sim.map
	for d in range(0, g.width):
		for x in range(g.width - 1 - d, g.width):
			var c := Vector2i(x, g.height - 1 - d)
			if g.in_bounds(c) and g.is_passable(c):
				return c
	return sim.map_center()


func colonists_at_point() -> Array:
	var out: Array = []
	var r := int(_ec().get("point_radius", 4))
	for c in sim.colonists.list:
		if not c.alive:
			continue
		var cell: Vector2i = c.cell
		if absi(cell.x - extract_cell.x) <= r and absi(cell.y - extract_cell.y) <= r:
			out.append(c)
	return out


func _escape_tick() -> void:
	if not counting:
		return
	t_left -= 1
	if t_left > 0:
		return
	counting = false
	var at := colonists_at_point()
	if at.is_empty():
		extract_failed += 1
		sim.bus.letter_received.emit("Pickup missed", str(_ec().get("lines", {}).get("missed", "")))
		return
	extracted = at.size()
	sim.bus.letter_received.emit("Pickup", str(_ec().get("lines", {}).get("won", "")))
	sim.endings.mark_won("escape")
# endregion


func tick() -> void:
	_fight_tick()
	_escape_tick()


func state_parts() -> Array:
	if assault_step < 0 and not assault_done and not contacted and assault_failed == 0:
		return []
	return [assault_step, assault_start, assault_done, assault_failed, contacted, paid, counting, t_left, extract_failed, extract_cell, extracted]
