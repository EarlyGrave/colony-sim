class_name ChipSystem
extends RefCounted
## AI chip operator (T4). A chip in a bench/smelter/assembler (def `chip_slots` > 0, never a miner)
## runs it without a colonist at `chip_speed`, with threat/waste multipliers, essence upkeep per
## day and a calibration due every `calibration_days` (done by a colonist job, see CalibrateJob).
## Numbers: data/chips.json. State lives here (building id -> entry), rebuilt by command replay.

var sim: Simulation
var cfg: Dictionary
## building id -> {cell: Vector2i, cal_tick: int, acc: float, starved: bool}
var slots: Dictionary = {}


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.chips


# --- Queries ------------------------------------------------------------------

func has_chip(b: Building) -> bool:
	return b != null and slots.has(b.id)


func can_slot(b: Building) -> bool:
	return b != null and int(b.def.get("chip_slots", 0)) > 0 and str(b.def.get("machine", "")) != "extractor"


func unlocked() -> bool:
	return not sim.research.gating or sim.research.is_done(str(cfg["tech"]))


## The chip recipe needs the `ai_chips` tech; every other station recipe is always allowed here.
func recipe_ok(recipe_id: String) -> bool:
	return recipe_id != str(cfg["recipe"]) or unlocked()


func calibration_due(b: Building) -> bool:
	return has_chip(b) and sim.tick - int(slots[b.id]["cal_tick"]) >= int(cfg["calibration_days"]) * sim.ticks_per_day


## Ticks until calibration is due (0 when due), -1 without a chip.
func ticks_to_calibration(b: Building) -> int:
	if not has_chip(b):
		return -1
	return maxi(0, int(cfg["calibration_days"]) * sim.ticks_per_day - (sim.tick - int(slots[b.id]["cal_tick"])))


func is_starved(b: Building) -> bool:
	return has_chip(b) and bool(slots[b.id]["starved"])


## Chip is installed, building intact, calibrated and its upkeep is paid.
func working(b: Building) -> bool:
	return has_chip(b) and not b.broken and not b.destroyed and not calibration_due(b) and not is_starved(b)


## True while the chip is actually doing work (benches: tech active; processors: a batch runs).
func busy(b: Building) -> bool:
	if not working(b):
		return false
	if b.def.get("research_bench", false):
		return ResearchOperator.active(sim) != ""
	return b.progress > 0


## Threat multiplier of one building for T1: chip_threat_mult while busy, else 1.0.
func threat_mult(b: Building) -> float:
	return float(cfg["chip_threat_mult"]) if busy(b) else 1.0


## Highest multiplier among busy chips (1.0 without chips); T1/T5 may read this.
func colony_threat_mult() -> float:
	var m := 1.0
	for id: int in _ids():
		var b := sim.buildings.get_by_id(id)
		if b != null:
			m = maxf(m, threat_mult(b))
	return m


func needs_calibration(b: Building) -> bool:
	return has_chip(b) and not b.broken and not b.destroyed and calibration_due(b)


## Bench-ticks per tick a chip bench adds to the active tech (operate contract {kind:"chip"}).
func bench_speed(b: Building) -> float:
	if not working(b):
		return 0.0
	return float(sim.defs.balance["research"]["bench_rate"]) * float(cfg["chip_speed"])


func describe(b: Building) -> String:
	if not has_chip(b):
		return ""
	if b.broken:
		return "AI chip: building broken"
	if is_starved(b):
		return "AI chip: stopped, no essence for upkeep"
	if calibration_due(b):
		return "AI chip: stopped, needs calibration"
	var left := ticks_to_calibration(b)
	return "AI chip: running, calibration in %.1f days" % (float(left) / float(sim.ticks_per_day))


# --- Commands (Simulation.install_chip / remove_chip) -------------------------------

func install(building_id: int) -> bool:
	var b := sim.buildings.get_by_id(building_id)
	if not can_slot(b) or has_chip(b) or b.broken or not unlocked():
		return false
	if not sim.items.consume_stored(str(cfg["item"]), 1, b.cell):
		return false
	sim.ledger.record_consumed(str(cfg["item"]), 1, "chip_install")
	slots[b.id] = {"cell": b.cell, "cal_tick": sim.tick, "acc": 0.0, "starved": false}
	return true


func remove(building_id: int) -> bool:
	var b := sim.buildings.get_by_id(building_id)
	if b == null or not has_chip(b):
		return false
	_return_chip(b.id, "chip_remove")
	return true


## Building removed: the chip drops to the ground (called from BuildingSystem._remove).
func spill(b: Building) -> void:
	if slots.has(b.id):
		_return_chip(b.id, "chip_spill")


func calibrate(b: Building) -> void:
	if has_chip(b):
		slots[b.id]["cal_tick"] = sim.tick


# --- Hooks used by building / research code ----------------------------------------

## Work steps a processor may take this tick (`unoperated_speed` without a chip; `processor_chip_speed` with one, 0 when stopped).
func steps(b: Building) -> int:
	if not has_chip(b):
		# R3X: an unoperated processor crawls (stateless, so saves stay exact); colonists add steps on top.
		var u := float(cfg.get("unoperated_speed", 1.0))
		return int(floor(float(sim.tick + 1) * u)) - int(floor(float(sim.tick) * u))
	if not working(b):
		return 0
	var e: Dictionary = slots[b.id]
	e["acc"] = float(e["acc"]) + float(cfg.get("processor_chip_speed", cfg["chip_speed"]))
	if float(e["acc"]) < 1.0 - 0.0001:
		return 0
	e["acc"] = float(e["acc"]) - 1.0
	return 1


## Scales contaminating output of a chip building (fraction rolled on sim.rng, only with a chip).
func scale_waste(b: Building, n: int) -> int:
	if n <= 0 or not has_chip(b):
		return n
	var f := float(n) * float(cfg["chip_waste_mult"])
	var whole := int(floor(f))
	var frac := f - float(whole)
	if frac > 0.0001 and sim.rng.randf() < frac:
		whole += 1
	return whole


# --- Tick -----------------------------------------------------------------------

func tick() -> void:
	if slots.is_empty():
		return
	var day_start := sim.tick % sim.ticks_per_day == 0
	for id: int in _ids():
		var b := sim.buildings.get_by_id(id)
		if b == null or b.destroyed:
			slots.erase(id)
			continue
		if b.broken:
			_return_chip(id, "chip_broken")  # a broken building loses its chip
			continue
		var e: Dictionary = slots[id]
		if day_start or bool(e["starved"]):
			e["starved"] = not _pay_upkeep(b)
		if b.def.get("research_bench", false) and busy(b):
			ResearchOperator.add_progress(sim, bench_speed(b))


func _pay_upkeep(b: Building) -> bool:
	var n := int(cfg["upkeep_per_day"])
	if n <= 0:
		return true
	var item := str(cfg["upkeep_item"])
	if not sim.items.consume_stored(item, n, b.cell):
		return false
	sim.ledger.record_consumed(item, n, "chip_upkeep")
	return true


func _return_chip(id: int, why: String) -> void:
	var e: Dictionary = slots[id]
	slots.erase(id)
	var item := str(cfg["item"])
	sim.ledger.record_produced(item, 1, why)
	sim.items.drop(e["cell"], item, 1)


func _ids() -> Array:
	var a: Array = slots.keys()
	a.sort()
	return a
