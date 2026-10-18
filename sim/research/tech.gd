class_name Tech
extends RefCounted
## Static helpers over the `data/research.json` dictionary (id -> tech def).


## Human-readable errors (empty = ok): unknown prereqs/unlock ids, bad tiers, cycles.
static func validate(techs: Dictionary, defs: Defs) -> Array[String]:
	var errs: Array[String] = []
	for id: String in techs:
		var t: Dictionary = techs[id]
		var tier := int(t.get("tier", -1))
		if tier < 0 or tier > 3:
			errs.append("tech %s: bad tier" % id)
		for p: String in t.get("prereqs", []):
			if not techs.has(p):
				errs.append("tech %s: unknown prereq %s" % [id, p])
			elif int(techs[p].get("tier", 0)) > tier:
				errs.append("tech %s: prereq %s has a higher tier" % [id, p])
		var cost: Dictionary = t.get("cost", {})
		if int(cost.get("bench_ticks", 0)) <= 0 or int(cost.get("essence", 0)) < 0:
			errs.append("tech %s: bad cost" % id)
		var un: Dictionary = t.get("unlocks", {})
		for b: String in un.get("buildings", []):
			if not defs.buildings.has(b):
				errs.append("tech %s: unknown building %s" % [id, b])
		for r: String in un.get("recipes", []):
			if not defs.recipes.has(r):
				errs.append("tech %s: unknown recipe %s" % [id, r])
		for r: String in un.get("rules", []):
			if not defs.rules.has(r):
				errs.append("tech %s: unknown rule %s" % [id, r])
	if has_cycle(techs):
		errs.append("research: circular prerequisites")
	return errs


static func has_cycle(techs: Dictionary) -> bool:
	var state: Dictionary = {}  # id -> 1 visiting, 2 done
	var ids: Array = techs.keys()
	ids.sort()
	for id: String in ids:
		if _visit(techs, id, state):
			return true
	return false


static func _visit(techs: Dictionary, id: String, state: Dictionary) -> bool:
	if state.get(id, 0) == 2:
		return false
	if state.get(id, 0) == 1:
		return true
	state[id] = 1
	for p: String in techs[id].get("prereqs", []):
		if techs.has(p) and _visit(techs, p, state):
			return true
	state[id] = 2
	return false
