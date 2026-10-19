class_name NeedsSystem
extends RefCounted
## Hunger and tiredness. Decays needs, sends hungry / tired colonists to eat
## or sleep (via JobSystem.request_override) and starves the unfed.
## Numbers live in data/needs.json.

var sim: Simulation
var cfg: Dictionary


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.needs


func state_of(c: Colonist) -> NeedsState:
	if c.needs == null:
		c.needs = NeedsState.new()
		c.needs.food = float(cfg["start_food"])
		c.needs.rest = float(cfg["start_rest"])
	return c.needs


func tick() -> void:
	for c in sim.colonists.list:
		if not c.alive:
			continue
		var n := state_of(c)
		n.food = maxf(0.0, n.food - float(cfg["food"]["decay_per_tick"]))
		if c.job == null or c.job.type != "sleep":
			n.rest = maxf(0.0, n.rest - float(cfg["rest"]["decay_per_tick"]))
		_ration(c, n)
		_starve(c, n)
		_decide(c, n)


## Called by SleepJob each tick spent asleep.
func rest_tick(c: Colonist, in_bed: bool) -> void:
	var n := state_of(c)
	var key := "gain_bed" if in_bed else "gain_floor"
	n.rest = minf(1.0, n.rest + float(cfg["rest"][key]))


func add_food(c: Colonist, nutrition: float) -> void:
	var n := state_of(c)
	n.food = minf(1.0, n.food + nutrition)
	n.starve_t = 0


func sleep_threshold() -> float:
	var r: Dictionary = cfg["rest"]
	return float(r["sleep_threshold_night"]) if sim.clock.is_night() else float(r["sleep_threshold_day"])


## Shelter ration: colonists who cannot reach the normal eat job (hidden, alarm,
## downed, sick) eat from stock at a reduced efficiency, so long raids don't starve them.
func _ration(c: Colonist, n: NeedsState) -> void:
	var r: Dictionary = cfg.get("ration", {})
	if r.is_empty() or n.food >= float(r["threshold"]) or sim.tick < n.ration_next:
		return
	var blocked: bool = c.hidden or sim.threats.in_lockdown(c.cell) or (c.health != null and c.health.downed) or c.is_sick(sim.tick)
	if not blocked:
		return
	for item: String in r["items"]:
		if sim.items.consume_stored(item, 1, c.cell):
			add_food(c, float(sim.defs.items[item]["nutrition"]) * float(r["efficiency"]))
			sim.ledger.record_consumed(item, 1, "eaten")
			sim.bus.colonist_ate.emit(c.id, item)
			n.ration_next = sim.tick + int(r["cooldown_ticks"])
			return


func _starve(c: Colonist, n: NeedsState) -> void:
	if n.food > 0.0:
		n.starve_t = 0
		return
	n.starve_t += 1
	if n.starve_t >= int(cfg["food"]["starve_interval_ticks"]):
		n.starve_t = 0
		sim.health.apply_damage(c, float(cfg["food"]["starve_damage"]), "torso", "starvation")
		sim.bus.colonist_starving.emit(c.id)


func _decide(c: Colonist, n: NeedsState) -> void:
	if n.next_check > sim.tick or c.hidden or sim.threats.in_lockdown(c.cell) or not c.alive:
		return
	if (c.health != null and c.health.downed) or c.is_sick(sim.tick):
		return
	var jt: String = c.job.type if c.job != null else ""
	if jt == "flee" or jt == "eat":
		return
	if n.food < float(cfg["food"]["eat_threshold"]):
		var j := _eat_job(c)
		if j != null:
			sim.jobs.request_override(c, j)
			return
		n.next_check = sim.tick + int(cfg["retry_ticks"])
	if jt == "sleep":
		return
	if n.rest < sleep_threshold():
		sim.jobs.request_override(c, _sleep_job(c))


# --- Job construction -----------------------------------------------------------------

## Best stored food: highest nutrition, then nearest. Null if none reachable.
func _eat_job(c: Colonist) -> EatJob:
	var best_cell := Vector2i(-1, -1)
	var best_nut := -1.0
	var best_d := 1 << 30
	for cell: Vector2i in sim.items.stacks:
		var item: String = sim.items.stacks[cell]["item"]
		if not sim.defs.items[item].has("nutrition") or not sim.items.is_stored(cell):
			continue
		if c.is_unreachable("eat:%d,%d" % [cell.x, cell.y], sim.tick):
			continue
		var nut := float(sim.defs.items[item]["nutrition"])
		var d := c.cell.distance_squared_to(cell)
		if nut < best_nut or (nut == best_nut and d >= best_d):
			continue
		if not sim.pathfinder.reachable(c.cell, cell):
			continue
		best_cell = cell
		best_nut = nut
		best_d = d
	if best_cell.x < 0:
		return null
	var j := EatJob.new(best_cell)
	j.fail_key = "eat:%d,%d" % [best_cell.x, best_cell.y]
	return j


func _sleep_job(c: Colonist) -> SleepJob:
	var best: Building = null
	var best_d := 1 << 30
	for b: Building in sim.buildings.list:
		if not b.def.get("bed", false) or not sim.jobs._free(c, "bed:%d" % b.id) or sim.health.bed_occupied(b.id):
			continue
		if not sim.pathfinder.reachable(c.cell, b.cell):
			continue
		var d := c.cell.distance_squared_to(b.cell)
		if d < best_d:
			best = b
			best_d = d
	var j := SleepJob.new(best.id if best != null else -1)
	if best != null:
		j.reservations.append("bed:%d" % best.id)
		j.fail_key = "bed:%d" % best.id
	return j
