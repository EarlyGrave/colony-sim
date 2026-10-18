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
	var site := int(opts.get("site", 0))
	if site != 0:
		sim.rng.seed = sim.seed_value * 31 + site * 104729


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
