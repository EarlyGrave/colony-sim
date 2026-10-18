class_name ShuttleSystem
extends RefCounted
## S1 Release Shuttle: after petition phase 4 build a Release Gantry, deliver release parts,
## launch, survive a pollution-scaled siege during the countdown. Gated by balance "s1_enabled".
## Siege waves reuse ThreatSystem.start_wave() (public); no edits in sim/threats.

var sim: Simulation
var parts := 0
var counting := false
var t_left := 0
var won := false
var launches := 0
var failures := 0
var _next_siege := 0
var _last_phase := ""


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func enabled() -> bool:
	return bool(sim.defs.balance.get("s1_enabled", false))


func _cfg() -> Dictionary:
	return sim.defs.shuttle


func parts_need() -> int:
	var m: Dictionary = _cfg().get("preset_mult", {})
	var mult := float(m.get(str(sim.opts.get("preset_id", "standard_term")), 1.0))
	return maxi(1, roundi(float(_cfg().get("parts_need", 40)) * mult))


func unlocked() -> bool:
	return enabled() and sim.petition.is_done(4)


func gantry() -> Building:
	var id := str(_cfg().get("gantry", "release_gantry"))
	for b in sim.buildings.list:
		if b.def_id == id and not b.destroyed:
			return b
	return null


func is_powered(g: Building) -> bool:
	if g == null or g.broken:
		return false
	return sim.power.factor_for(g) >= float(_cfg().get("min_power_factor", 0.5))


func phase() -> String:
	if not unlocked():
		return "locked"
	if won:
		return "won"
	if counting:
		return "countdown"
	var g := gantry()
	if g != null and parts >= parts_need() and is_powered(g):
		return "ready"
	return "building"


func state() -> Dictionary:
	var g := gantry()
	return {"phase": phase(), "parts": parts, "need": parts_need(), "t_left": t_left if counting else 0,
		"hp": int(g.hp) if g != null else 0, "max_hp": int(g.max_hp) if g != null else 0,
		"launches": launches, "failures": failures, "part_cost": (_cfg().get("part_cost", {}) as Dictionary).duplicate()}


## Consumes stored materials for as many parts as are affordable (up to the need). Returns parts added.
func deliver_parts() -> int:
	if not unlocked() or won or counting or gantry() == null:
		return 0
	var cost: Dictionary = _cfg().get("part_cost", {})
	var n := parts_need() - parts
	for item: String in cost:
		n = mini(n, sim.items.count_stored(item) / maxi(1, int(cost[item])))
	if n <= 0:
		return 0
	var keys := cost.keys()
	keys.sort()
	for item: String in keys:
		var amt := int(cost[item]) * n
		sim.items.consume_stored(item, amt, sim.map_center())
		sim.ledger.record_consumed(item, amt, "shuttle")
	parts += n
	_emit_phase()
	return n


func launch() -> bool:
	if phase() != "ready":
		return false
	counting = true
	launches += 1
	t_left = roundi(float(_cfg().get("countdown_days", 2.0)) * sim.ticks_per_day)
	_next_siege = sim.tick + int(_cfg().get("siege_first_delay_ticks", 200))
	_emit_phase()
	return true


func repair() -> bool:
	var g := gantry()
	if g == null or g.hp >= g.max_hp:
		return false
	var cost: Dictionary = _cfg().get("repair_cost", {})
	for item: String in cost:
		if sim.items.count_stored(item) < int(cost[item]):
			return false
	for item: String in cost:
		sim.items.consume_stored(item, int(cost[item]), g.cell)
		sim.ledger.record_consumed(item, int(cost[item]), "shuttle")
	g.hp = g.max_hp
	return true


func tick() -> void:
	if not counting:
		return
	if gantry() == null:
		_fail()
		return
	t_left -= 1
	if t_left <= 0:
		counting = false
		won = true
		_emit_phase()
		sim.bus.letter_received.emit("Release Shuttle", str(_cfg().get("win_letter", "")))
		sim.bus.shuttle_won.emit()
		return
	if sim.tick >= _next_siege:
		if not sim.threats.wave_active:
			sim.threats.start_wave()
		var base := float(_cfg().get("siege_interval_ticks", 1500))
		var f := 1.0 - float(_cfg().get("siege_pollution_speedup", 0.5)) * clampf(sim.contamination.fraction(), 0.0, 1.0)
		_next_siege = sim.tick + maxi(int(_cfg().get("siege_interval_min_ticks", 600)), roundi(base * f))


func _fail() -> void:
	counting = false
	t_left = 0
	failures += 1
	parts = int(floor(float(parts) * (1.0 - float(_cfg().get("parts_lost_frac", 0.5)))))
	_emit_phase()
	sim.bus.letter_received.emit("Launch failed", "The gantry fell. Half the release parts are lost; rebuild and try again.")


func _emit_phase() -> void:
	var p := phase()
	if p != _last_phase:
		_last_phase = p
		sim.bus.shuttle_phase.emit(p)


func has_state() -> bool:
	return parts > 0 or counting or won or launches > 0


func state_parts() -> Array:
	return ["s1", parts, counting, t_left, won, launches, failures]
