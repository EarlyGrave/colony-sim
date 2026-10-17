class_name PerkSystem
extends RefCounted
## Perks: per-skill points (skill level - perks learned in that skill), passive
## stat modifiers, active abilities with cooldowns, buffs and one-shot flags.
## Everything is read through mod()/has()/consume_flag(); data in data/perks.json.

var sim: Simulation
var _defs: Dictionary = {}   # perk id -> perk dict (insertion ordered)
var _caps: Dictionary = {}   # stat -> lowest allowed summed value


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	var data: Dictionary = p_sim.defs.perks
	for p: Dictionary in data.get("perks", []):
		_defs[str(p["id"])] = p
	_caps = data.get("caps", {})
	p_sim.listen(p_sim.bus.skill_leveled, _on_skill_leveled)


func perk_def(perk_id: String) -> Dictionary:
	return _defs.get(perk_id, {})


## Perk ids of one skill, in data order (for UI).
func perks_of_skill(skill: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in _defs:
		if str(_defs[id]["skill"]) == skill:
			out.append(id)
	return out


## State holder; created on demand (colonists without perks stay null).
func state_of(c: Colonist) -> ColonistPerks:
	if c.perks == null:
		c.perks = ColonistPerks.new()
	return c.perks


func has(c: Colonist, perk_id: String) -> bool:
	return c != null and c.perks != null and c.perks.learned.has(perk_id)


## Sum of passive effects + active buffs for `stat` (0.0 if none), with caps.
## `ctx` is reserved for conditional perks.
func mod(c: Colonist, stat: String, _ctx: Dictionary = {}) -> float:
	if c == null or c.perks == null:
		return 0.0
	var total := 0.0
	for id in c.perks.learned:
		var fx: Dictionary = _defs[id].get("effects", {})
		total += float(fx.get(stat, 0.0))
	for b: Dictionary in c.perks.buffs.values():
		total += float(b["stats"].get(stat, 0.0))
	if _caps.has(stat):
		total = maxf(total, float(_caps[stat]))
	return total


## True if a one-shot flag/buff is set (does not consume it).
func has_flag(c: Colonist, flag: String) -> bool:
	return c != null and c.perks != null and c.perks.buffs.has(flag)


## Consumes a one-shot flag/buff ("aimed_shot", "double_harvest", "masterwork",
## "no_waste_next_batch"). Returns whether it was set.
func consume_flag(c: Colonist, flag: String) -> bool:
	if not has_flag(c, flag):
		return false
	c.perks.buffs.erase(flag)
	return true


func level_in(c: Colonist, skill: String) -> int:
	return c.skills.level(skill) if c.skills != null else 0


func spent(c: Colonist, skill: String) -> int:
	var n := 0
	if c.perks != null:
		for id in c.perks.learned:
			if str(_defs[id]["skill"]) == skill:
				n += 1
	return n


func points_available(c: Colonist, skill: String) -> int:
	return maxi(0, level_in(c, skill) - spent(c, skill))


## "" if the perk can be learned, otherwise a reason code:
## unknown_perk, dead, already_learned, level, requires, no_points.
func can_learn(c: Colonist, perk_id: String) -> String:
	if not _defs.has(perk_id):
		return "unknown_perk"
	if c == null or not c.alive:
		return "dead"
	if has(c, perk_id):
		return "already_learned"
	var p: Dictionary = _defs[perk_id]
	var skill := str(p["skill"])
	if level_in(c, skill) < int(p["skill_level"]):
		return "level"
	for r: String in p["requires"]:
		if not has(c, r):
			return "requires"
	if points_available(c, skill) <= 0:
		return "no_points"
	return ""


func learn(c: Colonist, perk_id: String) -> bool:
	if can_learn(c, perk_id) != "":
		return false
	state_of(c).learned.append(perk_id)
	sim.bus.perk_learned.emit(c.id, perk_id)
	return true


## "" if usable, otherwise: unknown_perk, dead, not_learned, passive, cooldown.
func can_use(c: Colonist, perk_id: String) -> String:
	if not _defs.has(perk_id):
		return "unknown_perk"
	if c == null or not c.alive:
		return "dead"
	if not has(c, perk_id):
		return "not_learned"
	if str(_defs[perk_id]["type"]) != "active":
		return "passive"
	if cooldown_left(c, perk_id) > 0:
		return "cooldown"
	return ""


func cooldown_left(c: Colonist, perk_id: String) -> int:
	if c == null or c.perks == null:
		return 0
	return maxi(0, int(c.perks.cooldowns.get(perk_id, 0)) - sim.tick)


func use(c: Colonist, perk_id: String) -> bool:
	if can_use(c, perk_id) != "":
		return false
	var p: Dictionary = _defs[perk_id]
	if not ActiveEffects.apply(self, c, p["active"]):
		return false
	state_of(c).cooldowns[perk_id] = sim.tick + int(p["cooldown_ticks"])
	sim.bus.perk_used.emit(c.id, perk_id)
	return true


## Item cost of a respec: {"item": id, "count": n}.
func respec_cost() -> Dictionary:
	return sim.defs.perks["respec_cost"]


func can_respec(c: Colonist) -> bool:
	if c == null or not c.alive or c.perks == null or c.perks.learned.is_empty():
		return false
	var cost := respec_cost()
	return sim.items.count_stored(str(cost["item"])) >= int(cost["count"])


## Forgets all perks (points return) for the stored-item cost. Cooldowns stay.
func respec(c: Colonist) -> bool:
	if not can_respec(c):
		return false
	var cost := respec_cost()
	sim.items.consume_stored(str(cost["item"]), int(cost["count"]), c.cell)
	c.perks.learned.clear()
	c.perks.buffs.clear()
	return true


## Expires timed buffs.
func tick() -> void:
	for c in sim.colonists.list:
		if c.perks == null or c.perks.buffs.is_empty():
			continue
		for id: String in c.perks.buffs.keys():
			var until := int(c.perks.buffs[id]["until"])
			if until >= 0 and sim.tick >= until:
				c.perks.buffs.erase(id)


func _on_skill_leveled(colonist_id: int, skill_id: String, _level: int) -> void:
	var c := sim.colonists.get_by_id(colonist_id)
	if c == null:
		return
	var pts := points_available(c, skill_id)
	if pts > 0:
		sim.bus.perk_point_available.emit(colonist_id, skill_id, pts)
