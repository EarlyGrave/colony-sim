class_name TraitSystem
extends RefCounted
## Colonist traits v2 (data/traits.json). Effects are read only via mod()/has_tag().
## Acquired traits (hardened / resigned / settled) are granted by deterministic triggers.

var sim: Simulation
var cfg: Dictionary
var v3: TraitSystemV3 = null  # region F11W1: set when balance.traits_v3_enabled (this class is then a facade)
var _aura: Dictionary = {}  # region F11W1
var _aura_bucket := -1


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.traits
	v3 = sim.traits_v3  # region F11W1
	if v3 != null:  # region F11W1: TraitEvents owns acquisition, the v2 listeners stay off
		return
	sim.listen(sim.bus.colonist_rescued, _on_rescued)
	sim.listen(sim.bus.day_started, _on_day)
	sim.listen(sim.bus.mood_break_started, _on_break)


func resolve(id: String) -> String:
	if v3 != null:  # region F11W1: v2 ids map to v3 ids ("" = dropped)
		return str(v3.cfg.get("aliases", {}).get(id, id))
	return str(cfg.get("aliases", {}).get(id, id))


func def(id: String) -> Dictionary:
	if v3 != null:  # region F11W1
		return v3.def(resolve(id))
	return cfg["traits"].get(resolve(id), {})


## Sum of a stat over the colonist's traits (0.0 if none).
func mod(c: Colonist, stat: String) -> float:
	if c == null:
		return 0.0
	if v3 != null:  # region F11W1: v3 traits only; passives are added by explicit F11W3 hooks (no double count)
		return v3.mod(c, stat)
	var s := 0.0
	for t: String in c.bio.get("traits", []):
		s += float((def(t).get("effects", {}) as Dictionary).get(stat, 0.0))
	return s


func has_tag(c: Colonist, tag: String) -> bool:
	if c == null:
		return false
	if v3 != null:  # region F11W1
		return v3.has_tag(c, tag)
	for t: String in c.bio.get("traits", []):
		if (def(t).get("tags", []) as Array).has(tag):
			return true
	return false


# region traits F3c: one-line consumers for the stats that used to be text-only
## Carry capacity with the "carry" stat (+25% rounds to whole items, never below the base).
func carry_cap(c: Colonist, base: int) -> int:
	return maxi(base, roundi(float(base) * (1.0 + mod(c, "carry") + sim.passives.mod(c, "carry"))))  # F11W3


## Multiplier on xp gained in `skill`: xp_mult_all + xp_mult_<skill>.
func xp_mult(c: Colonist, skill: String) -> float:
	return maxf(0.0, 1.0 + mod(c, "xp_mult_all") + mod(c, "xp_mult_" + skill))


## Work-speed multiplier from night_owl / early_bird (work_night / work_day).
func shift_mult(c: Colonist) -> float:
	return maxf(0.1, 1.0 + mod(c, "work_night" if sim.clock.is_night() else "work_day"))


## Multiplier on the tainted-ground illness chance (essence_nose: mutation_risk).
func mutation_mult(c: Colonist) -> float:
	return maxf(0.0, 1.0 + mod(c, "mutation_risk"))


## F4e: added to the hit chance of a melee attacker with no equipped weapon.
func unarmed_hit(c: Colonist) -> float:
	return mod(c, "unarmed_hit")


## F4e: multiplier on wear a batch puts on a machine (machine_breakage -0.3 = 30% less wear).
func breakage_mult(c: Colonist) -> float:
	return maxf(0.0, 1.0 + mod(c, "machine_breakage"))


## F4e: multiplier on refining speed (refining_speed +0.1 = batches need 1/1.1 of the work).
func refine_speed(c: Colonist) -> float:
	return maxf(0.1, 1.0 + mod(c, "refining_speed"))


## F4e: whole quality tiers added to a craft roll (quality_tier -1 = one tier worse).
func quality_shift(c: Colonist) -> int:
	return roundi(mod(c, "quality_tier"))


## F4e: debt installment size for this colonist (installment_pct -0.05 = 5% smaller), at least 1.
func installment(c: Colonist, base: int) -> int:
	# region F11W3: no_installment / off_roll -> 0 (never overdue); installment_pct cap -0.4 on the traits + passives sum
	if sim.passives.rule(c, "no_installment") or sim.passives.rule(c, "off_roll"):
		return 0
	var pct := mod(c, "installment_pct")
	var pct_p := sim.passives.mod(c, "installment_pct")
	if pct_p != 0.0:
		pct = maxf(-0.4, pct + pct_p)
	# endregion
	return maxi(1, roundi(float(base) * maxf(0.0, 1.0 + pct)))


## F4e: extra movement gain per tick (move_speed +0.15 = 15% faster).
func move_bonus(c: Colonist) -> float:
	return mod(c, "move_speed")
# endregion


func has(c: Colonist, id: String) -> bool:
	if v3 != null:  # region F11W1
		return v3.has(c, resolve(id))
	return c != null and (c.bio.get("traits", []) as Array).has(id)


func acquired_count(c: Colonist) -> int:
	if v3 != null:  # region F11W1
		return v3.count_category(c, "scar") + v3.count_category(c, "mutation") + v3.count_category(c, "social")
	var n := 0
	for t: String in c.bio.get("traits", []):
		if bool(def(t).get("acquired", false)):
			n += 1
	return n


## Grants an acquired trait: false if unknown, already owned, or the acquired cap is reached.
func grant(c: Colonist, id: String) -> bool:
	if v3 != null:  # region F11W1: quests grant by id; v2 ids are aliased
		var tid := resolve(id)
		return tid != "" and v3.add(c, tid, "quest")
	var d := def(id)
	if c == null or not c.alive or d.is_empty() or not bool(d.get("acquired", false)) or has(c, id):
		return false
	if acquired_count(c) >= int(cfg.get("acquired_max", 1)):
		return false
	var arr: Array = c.bio.get("traits", [])
	arr.append(resolve(id))
	c.bio["traits"] = arr
	c.bio["work_speed"] = float(c.bio.get("work_speed", 1.0)) + float(d.get("effects", {}).get("work_speed", 0.0))
	return true


func _on_rescued(patient_id: int, _carrier: int) -> void:
	grant(sim.colonists.get_by_id(patient_id), "hardened")


func _on_break(cid: int, _kind: String) -> void:
	var c := sim.colonists.get_by_id(cid)
	if c != null:
		c.bio["calm_days"] = 0
		var arr: Array = c.bio.get("traits", [])
		if arr.has("settled"):  # settled leaves the trait when they break
			arr.erase("settled")
			c.bio["traits"] = arr


func _on_day(_d: int) -> void:
	var a: Dictionary = cfg.get("acquire", {})
	for c in sim.colonists.list:
		if not c.alive:
			continue
		c.bio["calm_days"] = int(c.bio.get("calm_days", 0)) + 1
		if int(c.bio["calm_days"]) >= int(a.get("calm_days", 30)):
			grant(c, "settled")
		var ds: DebtState = sim.debt.state_of(c) if sim.debt != null else null
		if ds != null:  # colonists without a debt state yet (e.g. spawned mid-tick) have no despair
			if ds.despair >= float(a.get("despair_level", 80)):
				c.bio["despair_days"] = int(c.bio.get("despair_days", 0)) + 1
				if int(c.bio["despair_days"]) >= int(a.get("despair_days", 5)):
					grant(c, "resigned")
			else:
				c.bio["despair_days"] = 0


## Weighted draw used by the generator. Fixed rng draws: 1 + max_traits.
func roll(rng: RandomNumberGenerator, block: String) -> Array[String]:
	var chosen: Array[String] = []
	var none := rng.randf() < float(cfg["none_chance"])
	for i in int(cfg["max_traits"]):
		var r := rng.randf()
		if none:
			continue
		var pool: Array[String] = []
		var total := 0.0
		for id: String in cfg["traits"]:
			var d: Dictionary = cfg["traits"][id]
			if bool(d.get("acquired", false)) or chosen.has(id):
				continue
			if d.has("block_only") and str(d["block_only"]) != block:
				continue
			var blocked := false
			for o: String in chosen:
				if (d.get("excludes", []) as Array).has(o) or (def(o).get("excludes", []) as Array).has(id):
					blocked = true
			if blocked:
				continue
			pool.append(id)
			total += float(cfg["rarity_weight"][d["rarity"]])
		var x := r * total
		for id in pool:
			x -= float(cfg["rarity_weight"][cfg["traits"][id]["rarity"]])
			if x < 0.0:
				chosen.append(id)
				break
	return chosen


# region F11W1
## Traits-v3-only stat (no passives): hooks for stats the passives worker adds on its own lines. 0.0 when off.
func v3_mod(c: Colonist, stat: String) -> float:
	return v3.mod(c, stat) if v3 != null and c != null else 0.0


## v3 trait ids of `c` (empty when the flag is off).
func ids_of(c: Colonist) -> Array[String]:
	return v3.list(c) if v3 != null else ([] as Array[String])


## Deterministic state for SaveGame.state_hash (only called with the flag on).
func state_parts() -> Array:
	var out: Array = []
	for c in sim.colonists.list:
		var counters: Dictionary = c.bio.get("trait_counters", {})
		var keys := counters.keys()
		keys.sort()
		var cp: Array = []
		for k in keys:
			cp.append([k, counters[k]])
		out.append([c.id, c.bio.get("traits_v3", []), cp])
	return out

# --- stat consumers added by F11W1: every helper returns the neutral value (1.0 / 0 / 0.0) with the flag off ---

## Work-speed multiplier for a work type (mining_speed / scrub_speed); data: traits_v3.json event_params.work_stats.
func work_mult(c: Colonist, work_type: String) -> float:
	if v3 == null:
		return 1.0
	var stat := str((v3.cfg.get("event_params", {}).get("work_stats", {}) as Dictionary).get(work_type, ""))
	return 1.0 if stat == "" else maxf(0.1, 1.0 + v3.mod(c, stat))


func research_mult(c: Colonist) -> float:
	return 1.0 if v3 == null else maxf(0.1, 1.0 + v3.mod(c, "research_speed"))


func heal_mult(c: Colonist) -> float:
	return 1.0 if v3 == null else v3.heal_mult(c)


func severity_mult(c: Colonist, illness: bool) -> float:
	return 1.0 if v3 == null else v3.severity_mult(c, illness)


func target_weight_mult(c: Colonist) -> float:
	return 1.0 if v3 == null else v3.target_weight_mult(c)


## Multiplier on thoughts by sign (thought_neg / thought_pos), on top of the per-thought stat.
func thought_sign_mult(c: Colonist, value: float) -> float:
	if v3 == null:
		return 1.0
	return maxf(0.0, 1.0 + v3.mod(c, "thought_neg" if value < 0.0 else "thought_pos"))


## False while the alarm has run for fewer than `alarm_delay` ticks (Heavy Sleeper reacts late).
func alarm_ready(c: Colonist) -> bool:
	if v3 == null or sim.trait_events == null:
		return true
	var d := v3.alarm_delay(c)
	return d <= 0 or sim.tick - sim.trait_events.alarm_since >= d


## Sum of `aura_<stat>` (mood / break) from the living block mates of `c`; cached per 30-tick bucket.
func aura(c: Colonist, stat: String) -> float:
	if v3 == null or sim.blocks == null:
		return 0.0
	var bucket := sim.tick / 30
	if bucket != _aura_bucket:
		_aura_bucket = bucket
		_aura.clear()
		for o in sim.colonists.list:
			if not o.alive:
				continue
			var b := sim.blocks.block_of(o)
			var d: Dictionary = _aura.get(b, {})
			for st: String in ["mood", "break"]:
				d[st] = float(d.get(st, 0.0)) + v3.mod(o, "aura_" + st)
			_aura[b] = d
	var own := v3.mod(c, "aura_" + stat)
	return float((_aura.get(sim.blocks.block_of(c), {}) as Dictionary).get(stat, 0.0)) - own


func aura_break_mult(c: Colonist) -> float:
	return 1.0 if v3 == null else maxf(0.0, 1.0 + aura(c, "break"))


## Block leaning (-2..2) for a path: the data value plus the members' leaning_<path> votes / divisor.
func lean_adjust(block: String, path: String, l: int) -> int:
	if v3 == null or sim.blocks == null:
		return l
	var votes := 0.0
	for c in sim.colonists.list:
		if c.alive and sim.blocks.block_of(c) == block:
			votes += v3.mod(c, "leaning_" + path)
	return clampi(l + roundi(votes / float(v3.cfg.get("event_params", {}).get("leaning_divisor", 4))), -2, 2)
# endregion

