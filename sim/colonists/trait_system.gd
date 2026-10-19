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
