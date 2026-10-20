class_name TraitSystem
extends RefCounted
## Colonist traits v2 (data/traits.json). Effects are read only via mod()/has_tag().
## Acquired traits (hardened / resigned / settled) are granted by deterministic triggers.

var sim: Simulation
var cfg: Dictionary


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.traits
	sim.listen(sim.bus.colonist_rescued, _on_rescued)
	sim.listen(sim.bus.day_started, _on_day)
	sim.listen(sim.bus.mood_break_started, _on_break)


func resolve(id: String) -> String:
	return str(cfg.get("aliases", {}).get(id, id))


func def(id: String) -> Dictionary:
	return cfg["traits"].get(resolve(id), {})


## Sum of a stat over the colonist's traits (0.0 if none).
func mod(c: Colonist, stat: String) -> float:
	if c == null:
		return 0.0
	var s := 0.0
	for t: String in c.bio.get("traits", []):
		s += float((def(t).get("effects", {}) as Dictionary).get(stat, 0.0))
	return s


func has_tag(c: Colonist, tag: String) -> bool:
	if c == null:
		return false
	for t: String in c.bio.get("traits", []):
		if (def(t).get("tags", []) as Array).has(tag):
			return true
	return false


# region traits F3c: one-line consumers for the stats that used to be text-only
## Carry capacity with the "carry" stat (+25% rounds to whole items, never below the base).
func carry_cap(c: Colonist, base: int) -> int:
	return maxi(base, roundi(float(base) * (1.0 + mod(c, "carry"))))


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
	return maxi(1, roundi(float(base) * maxf(0.0, 1.0 + mod(c, "installment_pct"))))


## F4e: extra movement gain per tick (move_speed +0.15 = 15% faster).
func move_bonus(c: Colonist) -> float:
	return mod(c, "move_speed")
# endregion


func has(c: Colonist, id: String) -> bool:
	return c != null and (c.bio.get("traits", []) as Array).has(id)


func acquired_count(c: Colonist) -> int:
	var n := 0
	for t: String in c.bio.get("traits", []):
		if bool(def(t).get("acquired", false)):
			n += 1
	return n


## Grants an acquired trait: false if unknown, already owned, or the acquired cap is reached.
func grant(c: Colonist, id: String) -> bool:
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
