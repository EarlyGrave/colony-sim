class_name ProgressionSystem
extends RefCounted
## Event-driven XP (data/xp.json). Work/attack XP stays in the job and combat
## systems. Contracts and other systems call award() directly.

var sim: Simulation
var cfg: Dictionary = {}
var milestones := 0  # region PW3: level milestones reached this run


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = p_sim.defs.xp
	p_sim.listen(p_sim.bus.day_started, _on_day)
	p_sim.listen(p_sim.bus.wave_repelled, _on_wave_repelled)
	p_sim.listen(p_sim.bus.colonist_rescued, _on_rescued)
	p_sim.listen(p_sim.bus.batch_refined, _on_batch)
	p_sim.listen(p_sim.bus.event_choice_resolved, _on_choice)
	p_sim.listen(p_sim.bus.skill_leveled, _on_leveled)  # region PW3


## Public hook (contracts etc.). Returns false if nothing was awarded.
## The single level-up path: emits skill_leveled once per level gained. `report` = also emit xp_awarded
## (off for per-tick work/attack xp).
func award(c: Colonist, skill: String, amount: float, reason: String, report: bool = true) -> bool:
	if c == null or not c.alive or c.skills == null or amount <= 0.0 or not c.skills.levels.has(skill):
		return false
	var before := c.skills.xp_total(sim.defs, skill)
	var lvl_before := c.skills.level(skill)
	c.skills.add_xp(sim.defs, skill, amount)
	if report:
		sim.bus.xp_awarded.emit(c.id, skill, c.skills.xp_total(sim.defs, skill) - before, reason)
	for l in range(lvl_before + 1, c.skills.level(skill) + 1):
		sim.bus.skill_leveled.emit(c.id, skill, l)
	return true


func _skill_for(c: Colonist, target: String) -> String:
	if c.skills == null:
		return ""
	if target == "best_skill" or target == "combat_best":
		var ids: Array = ["shooting", "melee"] if target == "combat_best" else c.skills.levels.keys()
		var best := ""
		var best_level := -1
		for id: String in ids:
			if c.skills.level(id) > best_level:
				best = id
				best_level = c.skills.level(id)
		return best
	return target


func _grant(key: String, actor: Colonist, extra: float = 0.0) -> void:
	var d: Dictionary = cfg.get(key, {})
	if d.is_empty():
		return
	var amount := float(d["amount"]) + extra
	if str(d["who"]) == "actor":
		if actor != null:
			award(actor, _skill_for(actor, str(d["target"])), amount, key)
		return
	for c in sim.colonists.list:
		if c.alive:
			award(c, _skill_for(c, str(d["target"])), amount, key)


func _on_day(_day: int) -> void:
	_grant("day_survived", null)


func _on_wave_repelled(wave_index: int) -> void:
	_grant("wave_repelled", null, float(cfg["wave_repelled"].get("per_wave_bonus", 0.0)) * (wave_index - 1))


func _on_rescued(_patient: int, carrier_id: int) -> void:
	_grant("colonist_rescued", sim.colonists.get_by_id(carrier_id))


func _on_batch(_building_id: int, _recipe: String) -> void:
	if sim.buildings.refined_batches == 1:
		_grant("first_refine", sim.buildings.batch_operator)


func _on_choice(_uid: int, _accepted: bool) -> void:
	_grant("event_choice", null)


## Generic event XP to every living colonist's best skill (used by contracts).
func grant_event_xp(amount: float, reason: String) -> void:
	for c in sim.colonists.list:
		if c.alive:
			var skill := _skill_for(c, "best_skill")
			if skill != "":
				award(c, skill, amount, reason)


# region PW3
## Level milestones (data/meta.json "milestones"): letter + leveled_up thought + legacy point.
func _on_leveled(cid: int, skill: String, level: int) -> void:
	var m: Dictionary = sim.defs.meta.get("milestones", {})
	var hit := false
	for v: Variant in m.get("levels", []):
		hit = hit or int(v) == level
	if not hit:
		return
	var c := sim.colonists.get_by_id(cid)
	if c == null or not c.alive:
		return
	milestones += 1
	if c.mood != null:
		sim.mood.add_thought(c, "leveled_up")
	var l: Dictionary = m.get("letters", {}).get(str(level), {})
	var nm: String = str(sim.defs.skills["skills"].get(skill, {}).get("label", skill))
	sim.bus.letter_received.emit(str(l.get("title", "")), str(l.get("text", "")) % [c.display_name, nm])
# endregion
