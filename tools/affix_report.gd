extends SceneTree
## E3: 1000 affix rolls per rarity: group distribution, duplicates, offense/defense split.
##   godot --headless --path . -s tools/affix_report.gd [-- --n=1000 --ilvl=10]


static func stats(defs: Defs, rarity: String, n: int, ilvl: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var weapons: Array = []
	var armors: Array = []
	var gk: Array = defs.gear.keys()
	gk.sort()
	for b: String in gk:
		if b.begins_with("_"):
			continue
		(weapons if (defs.gear[b].get("tags", []) as Array).has("weapon") else armors).append(b)
	var grp := {"offense": 0, "defense": 0, "utility": 0}
	var dups := 0
	var count_bad := 0
	for i in n:
		var pool: Array = weapons if i % 2 == 0 else armors  # 50/50 weapon vs armour class
		var base: String = pool[rng.randi() % pool.size()]
		var r := AffixRoller.roll(defs, base, rarity, ilvl, rng)
		var seen := {}
		for a in r:
			if seen.has(a[0]):
				dups += 1
			seen[a[0]] = true
			grp[AffixRoller.group_of(defs.affixes, a[0])] += 1
		if r.size() != int(defs.equipment["rarity"][rarity]["affixes"]):
			count_bad += 1
	var od: int = grp["offense"] + grp["defense"]
	return {"groups": grp, "dups": dups, "count_bad": count_bad, "offense_pct": 100.0 * grp["offense"] / maxf(1.0, od)}


func _init() -> void:
	var n := 1000
	var ilvl := 10
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--ilvl="):
			ilvl = int(a.substr(7))
	var defs := Defs.get_default()
	print("rarity    | offense | defense | utility | dups | wrong count | offense/(off+def) %%")
	for rarity: String in defs.equipment["rarity"]:
		var s := stats(defs, rarity, n, ilvl)
		print("%-9s | %7d | %7d | %7d | %4d | %11d | %5.1f" % [rarity, s["groups"]["offense"], s["groups"]["defense"], s["groups"]["utility"], s["dups"], s["count_bad"], s["offense_pct"]])
	quit()
