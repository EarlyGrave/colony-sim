class_name Legacy
extends RefCounted
## Computes the end-of-run summary and legacy score. Pure and deterministic.


static func summarize(sim: Simulation, reason: String) -> Dictionary:
	var w: Dictionary = sim.defs.meta["legacy"]
	var delivered := 0
	var fulfilled := 0
	for c: Dictionary in sim.contracts.list:
		if c.get("state", "") == "fulfilled":
			fulfilled += 1
			delivered += int(c["essence"])
	var freed := 0
	var stayed := 0
	for id: int in sim.debt.gone:
		if sim.debt.gone[id] == "left":
			freed += 1
	for id: int in sim.debt.states:
		if sim.debt.states[id].outcome == "stayed":
			stayed += 1
	var perks := 0
	for col in sim.colonists.list:
		if col.perks != null:
			perks += col.perks.learned.size()
	var days := sim.day()
	var pts := 0.0
	if days >= int(w["min_days_for_award"]):
		pts += days * float(w["per_day"])
	pts += fulfilled * float(w["per_contract"]) + delivered * float(w["per_essence_delivered"])
	pts += freed * float(w["per_prisoner_freed"]) + stayed * float(w["per_prisoner_stayed"])
	pts += perks * float(w["per_perk_learned"])
	pts += sim.debt.legacy_points * float(w["debt_points_weight"])
	pts += sim.progression.milestones * float(w.get("per_milestone", 0.0))  # region PW3
	return {
		"reason": reason, "seed": sim.seed_value, "days": days,
		"contracts": fulfilled, "essence": delivered, "freed": freed, "stayed": stayed,
		"perks": perks, "debt_points": sim.debt.legacy_points,
		"contamination": sim.contamination.level, "legacy": int(floor(pts)),
	}


# region NG
## Snapshot for MetaState.finish_sentence (read-only; summarize() is unchanged).
static func ng_snapshot(sim: Simulation, result: String, preset_id := "") -> Dictionary:
	var left := 0
	var paid := 0
	for id: int in sim.debt.states:
		var st: DebtState = sim.debt.states[id]
		paid += st.paid
		if not sim.debt.gone.has(id):
			left += st.remaining()
	var cols: Array = []
	for c in sim.colonists.list:
		if not c.alive:
			continue
		cols.append({"id": c.id, "name": c.display_name, "skills": c.skills.levels.duplicate(),
			"perks": (c.perks.learned.duplicate() if c.perks != null else []),
			"traits": (c.bio.get("traits", []) as Array).duplicate()})
	return {"seed": sim.seed_value, "days": sim.day(), "result": result, "preset": preset_id,
		"debt_left": left, "debt_paid": paid, "colonists": cols, "techs": sim.research.done.duplicate()}
# endregion
