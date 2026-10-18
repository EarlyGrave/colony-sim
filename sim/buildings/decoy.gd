class_name Decoy
extends RefCounted
## "Beacon of Penance" decoys (region T2): fortified high-threat buildings that lure creatures
## away from belts and machines. Numbers live in the building def (data/buildings.json "decoy").
## State per building lives in `Building.decoy` (plain Dictionary, hashed only when non-empty).
##  - lit beacon: burns 1 fuel item per `burn_ticks`, unlit threat = threat * unlit_mult
##  - bell: `trigger_bell` -> threat x burst_mult for burst_ticks, then cooldown_ticks


static func is_decoy(b: Building) -> bool:
	return b.def.has("decoy")


static func is_lit(b: Building) -> bool:
	return int(b.decoy.get("fuel_left", 0)) > 0


static func burst_left(b: Building) -> int:
	return int(b.decoy.get("burst_left", 0))


static func cooldown_left(b: Building) -> int:
	return int(b.decoy.get("cooldown_left", 0))


## Current attention value. Callers: `Building.threat_now` (T1) may delegate here for decoys.
static func threat_now(b: Building) -> float:
	var cfg: Dictionary = b.def.get("decoy", {})
	var t := float(b.def.get("threat", 0.0))
	if b.destroyed or b.broken:
		return 0.0
	if cfg.has("fuel_item") and not is_lit(b):
		t *= float(cfg.get("unlit_mult", 0.25))
	if burst_left(b) > 0:
		t *= float(cfg.get("burst_mult", 3.0))
	return t


## Per-tick upkeep (fuel burning, burst/cooldown timers). Called from BuildingSystem.tick_decoys.
static func tick(b: Building, sim: Simulation) -> void:
	if b.destroyed or b.broken:
		return
	var cfg: Dictionary = b.def["decoy"]
	if cfg.has("fuel_item"):
		var fuel := str(cfg["fuel_item"])
		if not is_lit(b) and int(b.input.get(fuel, 0)) > 0:
			b.input[fuel] = int(b.input[fuel]) - 1
			if int(b.input[fuel]) <= 0:
				b.input.erase(fuel)
			b.decoy["fuel_left"] = int(cfg["burn_ticks"])
			sim.contamination.level += float(cfg.get("pollution_per_burn", 0.0))
		if is_lit(b):
			b.decoy["fuel_left"] = int(b.decoy["fuel_left"]) - 1
	if burst_left(b) > 0:
		b.decoy["burst_left"] = burst_left(b) - 1
		if burst_left(b) == 0:
			b.decoy["cooldown_left"] = int(cfg["cooldown_ticks"])
	elif cooldown_left(b) > 0:
		b.decoy["cooldown_left"] = cooldown_left(b) - 1


## Starts the burst if possible. Essence is taken from storage; any shortfall is recorded as debt
## (ledger event "decoy_essence_debt"), so the bell is never blocked by an empty stockpile.
static func trigger_bell(b: Building, sim: Simulation) -> bool:
	if b == null or b.destroyed or b.broken or not b.def.has("decoy"):
		return false
	var cfg: Dictionary = b.def["decoy"]
	if not cfg.has("burst_ticks") or burst_left(b) > 0 or cooldown_left(b) > 0:
		return false
	var item := str(cfg["essence_item"])
	var cost := int(cfg["essence_cost"])
	var paid := mini(cost, sim.items.count_stored(item))
	if paid > 0:
		sim.items.consume_stored(item, paid, b.cell)
		sim.ledger.record_consumed(item, paid, "bell")
	if cost > paid:
		sim.ledger.record_event("decoy_essence_debt", cost - paid)
	b.decoy["burst_left"] = int(cfg["burst_ticks"])
	return true
