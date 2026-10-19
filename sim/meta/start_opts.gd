class_name StartOpts
extends RefCounted
## Applies deterministic start options (from meta unlocks) to a fresh game.
## Keys: start_rules: Array[String], start_xp: float, reveal_forecast: bool,
## scout: int (cells to pre-designate), crate: Dictionary item->n,
## contamination: float (starting level), site: int (landing site index).
## map_w / map_h: int map size (read by Simulation.start_new_game, not here).
## Never touches sim.rng except the explicit site reseed.


static func apply(sim: Simulation, opts: Dictionary) -> void:
	if opts.is_empty():
		return
	# region R4b: expedition opts. biome (String) is read by MapGenerator, crew/supplies by
	# Simulation._place_crew_colony, no_refining by Simulation.can_place_building; nothing to do here.
	# endregion
	for r: Variant in opts.get("start_rules", []):
		if sim.rules.has(str(r)):
			sim.rules[str(r)] = true
	var xp := float(opts.get("start_xp", 0.0))
	if xp > 0.0:
		for c in sim.colonists.list:
			var best := ""
			var best_lvl := -1
			for s: String in c.skills.levels:  # insertion order, ties -> first
				if int(c.skills.levels[s]) > best_lvl:
					best_lvl = int(c.skills.levels[s])
					best = s
			if best != "":
				c.skills.add_xp(sim.defs, best, xp)
	var contam := float(opts.get("contamination", 0.0))
	if contam > 0.0:
		sim.contamination.level = contam
		sim.contamination._last_level = contam
	if bool(opts.get("reveal_forecast", false)):
		sim.contamination.revealed = true
		sim.bus.forecast_revealed.emit()
	var n := int(opts.get("scout", 0))
	if n > 0:
		_scout(sim, n)
	var crate: Dictionary = opts.get("crate", {})
	if not crate.is_empty():
		var at := sim.map_center() + Vector2i(3, -1)
		var items: Array = crate.keys()
		items.sort()  # JSON round-trips sort keys: drop in sorted order everywhere
		for item: String in items:
			sim.ledger.record_produced(item, int(crate[item]), "meta_crate")
			sim.items.drop(at, item, int(crate[item]))
	_apply_ng(sim, opts)  # region NG
	var site := int(opts.get("site", 0))
	if site != 0:
		sim.rng.seed = sim.seed_value * 31 + site * 104729


# region NG
## Next Sentence carry-over: veteran, start techs, carried debt. All keys optional.
static func _apply_ng(sim: Simulation, opts: Dictionary) -> void:
	var techs: Array = opts.get("start_techs", [])
	if not techs.is_empty():
		for t: Variant in techs:
			var id := str(t)
			if sim.defs.research.has(id) and not sim.research.done.has(id):
				sim.research.done.append(id)
		sim.research.done.sort()
	var vet: Dictionary = opts.get("veteran", {})
	if not vet.is_empty() and not sim.colonists.list.is_empty():
		var c: Colonist = sim.colonists.list[0]
		for x in sim.colonists.list:
			if x.id < c.id:
				c = x
		if str(vet.get("name", "")) != "":
			c.display_name = str(vet["name"])
		var sk: Dictionary = vet.get("skills", {})
		for k: Variant in sk:
			if c.skills.levels.has(str(k)):
				c.skills.levels[str(k)] = maxi(int(c.skills.levels[str(k)]), int(sk[k]))
		c.skills.mark_joined()
		var pid := str(vet.get("perk_id", ""))
		if pid != "" and not sim.perks.perk_def(pid).is_empty():
			var cp := sim.perks.state_of(c)
			if not cp.learned.has(pid):
				cp.learned.append(pid)
	var carry := int(opts.get("carry_debt", 0))
	if carry > 0:
		sim.debt.add_carry(carry)
# endregion


# region O3
## Preset overrides as start opts (keys: wave_mult, waste_mult, debt_mult, crate, hint_density).
## Only non-neutral values are emitted, so standard_term yields {} (identical to today).
## wave_mult/waste_mult/debt_mult are read by ThreatSystem/ContaminationSystem/DebtSystem.
static func preset_opts(defs: Defs, id: String) -> Dictionary:
	var p: Dictionary = defs.presets.get("presets", {}).get(id, {})
	var o := {}
	for pair: Array in [["wave_strength_mult", "wave_mult"], ["waste_mult", "waste_mult"], ["starting_debt_mult", "debt_mult"]]:
		var v := float(p.get(pair[0], 1.0))
		if v != 1.0:
			o[pair[1]] = v
	if id != "":  # region K2: milestones read the preset id for review demands
		o["preset_id"] = id
	if p.has("audit_interval_days"):  # region K1
		o["audit_days"] = float(p["audit_interval_days"])
		o["calm_mult"] = float(p.get("calm_after_hit_days", 1.0))
		if float(p.get("wave_interval_mult", 1.0)) != 1.0:
			o["wave_interval_mult"] = float(p["wave_interval_mult"])
	var crate: Dictionary = p.get("crate", {})
	if not crate.is_empty():
		o["crate"] = crate.duplicate()
	var hd := str(p.get("hint_density", "new"))
	if hd != "new":
		o["hint_density"] = hd
	return o


## Merges preset opts into `o` (crates add up).
static func merge_preset(o: Dictionary, defs: Defs, id: String) -> void:
	var p := preset_opts(defs, id)
	for k: String in p:
		if k == "crate":
			var c: Dictionary = o.get("crate", {}).duplicate()
			for item: String in p["crate"]:
				c[item] = int(c.get(item, 0)) + int(p["crate"][item])
			o["crate"] = c
		else:
			o[k] = p[k]
# endregion


static func _scout(sim: Simulation, n: int) -> void:
	var center := sim.map_center()
	var cells: Array = []
	for y in sim.map.height:
		for x in sim.map.width:
			var c := Vector2i(x, y)
			if sim.map.is_deposit(c):
				var d := (c - center)
				cells.append([d.x * d.x + d.y * d.y, y * sim.map.width + x, c])
	cells.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for i in mini(n, cells.size()):
		sim.map.set_mine_designated(cells[i][2], true)
