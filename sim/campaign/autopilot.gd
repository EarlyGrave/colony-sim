class_name Autopilot
extends RefCounted
## Analytic per-day economy of an unattended outpost. Pure functions over a plain-data
## ledger Dictionary; never touches any Simulation or sim.rng (raid rolls use their own stream).
##
## ledger: {miners:int, resource:String, purity:String, biome:String, seed:int,
##          buffer:{item:int}, inbox:{item:int}, supplies:{item:int}, integrity:int,
##          lost:bool, days:int, raids:int}


static func new_ledger(biome: String, p_seed: int, cfg: Dictionary, resource := "") -> Dictionary:
	return {
		"miners": 0, "resource": resource, "purity": str(cfg.get("default_purity", "normal")),
		"biome": biome, "seed": p_seed, "buffer": {}, "inbox": {}, "supplies": {},
		"integrity": int(cfg.get("integrity_max", 100)), "lost": false, "days": 0, "raids": 0,
	}


static func buffer_total(ledger: Dictionary) -> int:
	var n := 0
	for k: String in ledger["buffer"]:
		n += int(ledger["buffer"][k])
	return n


## Items produced in one full day by the ledger's miners (before upkeep and cap).
static func day_yield(ledger: Dictionary, defs: Defs, cfg: Dictionary, ticks_per_day: int) -> int:
	var rdef: Dictionary = defs.resources.get(ledger["resource"], {})
	var base := float(rdef.get("base_rate", 10.0))
	var pm: Dictionary = rdef.get("purity_mult", {"impure": 0.5, "normal": 1.0, "pure": 2.0})
	var purity := float(pm.get(ledger["purity"], 1.0))
	var ym := float(defs.biomes.get(ledger["biome"], {}).get("yield_mult", 1.0))
	var rate_ticks := maxi(1, int(cfg["rate_ticks"]))
	return floori(float(int(ledger["miners"])) * base * purity * ym * float(ticks_per_day) / float(rate_ticks))


static func _upkeep_need(ledger: Dictionary, cfg: Dictionary, item: String) -> int:
	var per: int = int(cfg.get("upkeep", {})[item])
	return per * int(ledger["miners"]) if bool(cfg.get("upkeep_per_miner_per_day", true)) else per


## Advances one map-day. Returns event names ("raid", "lost") for the campaign log.
static func advance_day(ledger: Dictionary, defs: Defs, cfg: Dictionary, ticks_per_day: int) -> Array:
	var events: Array = []
	if bool(ledger["lost"]):
		return events
	ledger["days"] = int(ledger["days"]) + 1
	var fed := true
	var sup: Dictionary = ledger["supplies"]
	var up: Dictionary = cfg.get("upkeep", {})
	for item: String in up:
		if int(sup.get(item, 0)) < _upkeep_need(ledger, cfg, item):
			fed = false
	if fed:  # a short day produces nothing and eats nothing
		for item: String in up:
			sup[item] = int(sup.get(item, 0)) - _upkeep_need(ledger, cfg, item)
		var y := day_yield(ledger, defs, cfg, ticks_per_day)
		var add := mini(y, maxi(0, int(cfg["buffer_cap"]) - buffer_total(ledger)))
		if add > 0:
			var item_id: String = str(defs.resources.get(ledger["resource"], {}).get("item", ledger["resource"]))
			ledger["buffer"][item_id] = int(ledger["buffer"].get(item_id, 0)) + add
	# raid roll: stateless stream keyed by (outpost seed, day); never sim.rng
	var hazard := int(defs.biomes.get(ledger["biome"], {}).get("hazard", 0))
	if hazard > 0:
		var r := RandomNumberGenerator.new()
		r.seed = (int(ledger["seed"]) ^ 0x0A07) + int(ledger["days"]) * 7919
		if r.randf() < float(hazard) * float(cfg["raid_chance_per_hazard"]):
			ledger["raids"] = int(ledger["raids"]) + 1
			ledger["integrity"] = maxi(0, int(ledger["integrity"]) - hazard * int(cfg["raid_damage_per_hazard"]))
			events.append("raid")
			if int(ledger["integrity"]) <= 0:
				ledger["lost"] = true
				events.append("lost")
	return events
