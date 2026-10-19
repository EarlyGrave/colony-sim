class_name AffixRoller
extends RefCounted
## E3: rolls affixes for a gear base. Pure function of (defs, base, rarity, ilvl, rng); iterates ids in sorted order.


static func tier_for(rules: Dictionary, ilvl: int) -> int:
	var t := 0
	var br: Array = rules.get("tier_by_ilvl", [0])
	for i in br.size():
		if ilvl >= int(br[i]):
			t = i
	return t


static func group_of(aff: Dictionary, id: String) -> String:
	for g: String in aff["groups"]:
		if (aff["groups"][g] as Array).has(id):
			return g
	return ""


## Returns [[affix_id, value], ...]; count = equipment.json rarity.affixes (fewer only if candidates run out).
static func roll(defs: Defs, base: String, rarity: String, ilvl: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var n := int(defs.equipment.get("rarity", {}).get(rarity, {}).get("affixes", 0))
	if n <= 0 or not defs.gear.has(base):
		return out
	var aff: Dictionary = defs.affixes
	var rules: Dictionary = aff["rules"]
	var tags: Array = defs.gear[base].get("tags", [])
	var used_pos := {"prefix": 0, "suffix": 0}
	var used_grp := {}
	var ids: Array = aff["affixes"].keys()
	ids.sort()
	var tier := tier_for(rules, ilvl)
	for _i in n:
		var cands: Array = []
		var total := 0.0
		for id: String in ids:
			var a: Dictionary = aff["affixes"][id]
			if _used(out, id) or not _tag_ok(a, tags):
				continue
			if int(used_pos[a["pos"]]) >= int(rules["max_" + str(a["pos"])]):
				continue
			var g := group_of(aff, id)
			if int(used_grp.get(g, 0)) >= int(rules["max_per_group"].get(g, 99)):
				continue
			cands.append(id)
			total += float(a.get("weight", 1))
		if cands.is_empty():
			break
		var r := rng.randf() * total
		var pick: String = cands[cands.size() - 1]
		for id: String in cands:
			r -= float(aff["affixes"][id].get("weight", 1))
			if r < 0.0:
				pick = id
				break
		var pa: Dictionary = aff["affixes"][pick]
		var tiers: Array = pa["tiers"]
		var rg: Array = tiers[mini(tier, tiers.size() - 1)]
		var v: float
		if bool(pa.get("int", false)):
			v = float(rng.randi_range(int(rg[0]), int(rg[1])))
		else:
			v = snappedf(rng.randf_range(float(rg[0]), float(rg[1])), 0.0001)
		out.append([pick, v])
		used_pos[pa["pos"]] = int(used_pos[pa["pos"]]) + 1
		var gg := group_of(aff, pick)
		used_grp[gg] = int(used_grp.get(gg, 0)) + 1
	return out


static func _used(out: Array, id: String) -> bool:
	for a in out:
		if a[0] == id:
			return true
	return false


static func _tag_ok(a: Dictionary, tags: Array) -> bool:
	for t in a.get("tags_any", []):
		if tags.has(t):
			return true
	return false


## "Plated Kevlar Vest of Vigor" from a base display name.
static func display_name(defs: Defs, base: String, affixes: Array) -> String:
	var nm := str(defs.gear.get(base, {}).get("name", base))
	for a in affixes:
		var d: Dictionary = defs.affixes["affixes"].get(a[0], {})
		if d.get("pos", "") == "prefix":
			nm = str(d["name"]) % nm
	for a in affixes:
		var d: Dictionary = defs.affixes["affixes"].get(a[0], {})
		if d.get("pos", "") == "suffix":
			nm = str(d["name"]) % nm
	return nm
