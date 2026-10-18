class_name QaBot
extends RefCounted
## Deterministic "player" for QA tests: issues every kind of command from the
## sim state only (no randomness of its own), so two runs are comparable.

const Scen := preload("res://tests/scenario.gd")


## Runs `ticks` ticks, acting every `period` ticks. Returns the number of commands issued.
static func play(sim: Simulation, ticks: int, period := 150) -> int:
	var issued := 0
	var n := 0
	while ticks > 0 and sim.game_over_reason == "":
		issued += act(sim, n)
		n += 1
		var chunk := mini(period, ticks)
		sim.run_ticks(chunk)
		ticks -= chunk
	return issued


static func act(sim: Simulation, n: int) -> int:
	var center := sim.map_center()
	var cols: Array = sim.colonists.list.filter(func(c: Colonist) -> bool: return c.alive)
	var issued := 0
	if n == 0 and sim.has_meta("qa_setup"):
		Scen.standard_colony(sim, 0)
		issued += 1
	# By day 4 the bot has asked for 1 miner + belts + 1 smelter (colonists build them).
	if sim.day() >= 2 and not sim.has_meta("qa_chain"):
		sim.set_meta("qa_chain", true)
		if not Scen.build_chain(sim, true).is_empty():
			issued += 1
	# Always answer whatever is waiting (events, crises, contracts, debts).
	for p in sim.storyteller.pending.duplicate():
		sim.answer_event(int(p.get("uid", 0)), n % 2 == 0)
		issued += 1
	for cid in sim.crises.pending.duplicate():
		var id := str(cid["id"]) if cid is Dictionary else str(cid)
		var opts: Dictionary = sim.defs.crises["crises"].get(id, {}).get("options", {})
		for o: String in opts:
			if sim.resolve_crisis(id, o):
				issued += 1
				break
	for k in sim.contracts.list:
		match str(k.get("state", "")):
			"offered":
				if n % 3 == 0:
					sim.accept_contract(int(k["id"]))
				else:
					sim.decline_contract(int(k["id"]))
				issued += 1
			"active":
				sim.deliver_contract(int(k["id"]))
				issued += 1
	if cols.is_empty():
		return issued
	var c: Colonist = cols[n % cols.size()]
	match n % 12:
		0:
			sim.designate_mine(center + Vector2i(n % 9 - 4, 3 + n % 5), true)
		1:
			sim.set_zone(center + Vector2i(-6 - n % 3, 2 + n % 3), "stockpile")
			sim.set_zone_priority(center + Vector2i(-6, 2), n % 3)
			sim.set_zone_filter(center + Vector2i(-6, 2), "waste", n % 2 == 0)
		2:
			var spot := Scen.find_spot(sim, "workbench", center + Vector2i(5, 3), 0)
			sim.place_building("workbench", spot)
			sim.place_building("turret", Scen.find_spot(sim, "turret", center + Vector2i(4 - n % 7, -4), 0))
		3:
			for b in sim.buildings.list:
				if b.def_id == "workbench":
					var bid := sim.add_bill(b.id, "machine_parts", "count", 2)
					sim.update_bill(b.id, bid, "forever", 1, n % 2 == 0)
					if n % 24 == 15:
						sim.remove_bill(b.id, bid)
					issued += 1
					break
		4:
			sim.set_rule("engineer_repairs", n % 2 == 0)
			sim.set_work_priority(c.id, "mining", n % 5)
			sim.set_alarm(n % 24 == 4)
		5:
			sim.set_drafted(c.id, true)
			sim.order_move(c.id, center + Vector2i(-2, 4))
			for e in sim.threats.enemies:
				sim.order_attack(c.id, e.id)
				break
		6:
			sim.set_drafted(c.id, false)
			sim.set_alarm(false)
		7:
			for pid in sim.defs.perks.get("perks", sim.defs.perks):
				if sim.learn_perk(c.id, str(pid)):
					break
			for pid in sim.defs.perks.get("perks", sim.defs.perks):
				if sim.use_perk(c.id, str(pid)):
					break
			if n % 36 == 31:
				sim.respec_perks(c.id)
		8:
			sim.pay_debt(c.id, 20)
			sim.set_quota(c.id, 2 + n % 4)
			sim.choose_payoff(c.id, n % 2 == 0)
		9:
			for b in sim.buildings.list:
				if b.def_id == "turret" or b.def_id == "hq":
					sim.set_turret_ammo_policy(b.id, "conserve" if n % 2 == 0 else "normal")
					break
			sim.deconstruct(center + Vector2i(4 - (n - 9) % 7, -4)) if n % 24 == 21 else null
		10:
			sim.set_patrol_route([center + Vector2i(-5, -5), center + Vector2i(5, -5), center + Vector2i(5, 5)] if n % 2 == 0 else [])
		11:
			sim.purify_cell(center + Vector2i(n % 5, n % 4))
	return issued + 1


## Wide fingerprint of the observable state, far beyond `SaveGame.state_hash`.
static func full_hash(sim: Simulation) -> int:
	return var_to_str(parts_of(sim)).hash()


## Named fingerprint pieces, for locating a divergence.
static func parts_of(sim: Simulation) -> Array:
	var parts: Array = [SaveGame.state_hash(sim), sim.rng.state, sim.ledger.produced, sim.ledger.consumed]
	for o: Object in [sim.contamination, sim.threats, sim.storyteller, sim.crises, sim.contracts, sim.debt, sim.mutation]:
		parts.append(_dump(o))
	for col in sim.colonists.list:
		for o: Object in [sim.debt.state_of(col), sim.mood.state_of(col), sim.health.state_of(col), sim.needs.state_of(col), sim.perks.state_of(col)]:
			parts.append(_dump(o))
	for b in sim.buildings.list:
		parts.append(sim.crafting.bills_of(b).size() if b.def_id == "workbench" else 0)
	for e in sim.threats.enemies:
		parts.append([e.id, e.cell, e.hp])
	return parts


static func _dump(o: Object) -> Array:
	var out: Array = []
	if o == null:
		return out
	for p in o.get_property_list():
		if not (p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) or p["name"] in ["sim", "cfg"]:
			continue
		var v: Variant = o.get(p["name"])
		if v is Object or v is Callable:
			continue
		if v is Array and not v.is_empty() and v[0] is Object:
			continue
		if v is Dictionary and not v.is_empty() and v.values()[0] is Object:
			continue
		out.append([p["name"], v])
	return out


# region L5
## Logistics-2 QA profile (bot_report "power"). Deterministic, uses only recorded commands + data. Day 3: techs
## splitting/electrification are granted free (like the chip profile), a 1-miner line is built with a splitter feeding
## two smelters and a merger into storage_in (second line), then a pole line + coal generator; the generator is kept
## fuelled by hand-feeding its input buffer (QA shortcut, belts to a coal miner come with the coal-node switch).
## Hooks are probed with has_method / get(), so the profile is a no-op until the L1/L2/L3 commands exist.
## Layout (t = miner cell): miner t, belt t+2..t+5, splitter t+4, smelters t+6 and t+(6,2), merger t+(9,0), store t+12.
static func l2_step(sim: Simulation, r: Dictionary) -> void:
	var d := sim.day()
	if d < 3:
		return
	for t in ["splitting", "electrification"]:
		if sim.research != null and not sim.research.done.has(t):
			sim.research.done.append(t)
	if not sim.has_meta("qa_l2_site"):
		sim.set_meta("qa_l2_site", _l2_build(sim, r))
	var site: Variant = sim.get_meta("qa_l2_site")
	if site is Vector2i and sim.get("power") != null:
		_l2_power(sim, site as Vector2i, r)
		for b in sim.buildings.list:
			if b.def_id == "coal_generator" and not b.broken and int(b.input.get("coal", 0)) < 10:
				sim.ledger.record_produced("coal", 10, "qa")
				b.input["coal"] = int(b.input.get("coal", 0)) + 10


static func _l2_build(sim: Simulation, r: Dictionary) -> Variant:
	if not sim.has_method("place_belt_node"):
		return false
	var center := sim.map_center()
	var nodes: Array[Vector2i] = []
	for c in sim.map.node_cells():
		if sim.map.node_resource(c) == "essence_ore":
			nodes.append(c)
	nodes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center) or (a.distance_squared_to(center) == b.distance_squared_to(center) and a < b))
	for n in nodes:
		for t: Vector2i in [n, n + Vector2i(-1, 0), n + Vector2i(0, -1), n + Vector2i(-1, -1)]:
			var site: Variant = _l2_try(sim, t, r)
			if site != null:
				return site
	return false


static func _l2_try(sim: Simulation, t: Vector2i, r: Dictionary) -> Variant:
	var path_a: Array = []
	for x in range(2, 6):
		path_a.append(t + Vector2i(x, 0))
	var path_b: Array = [t + Vector2i(4, 1), t + Vector2i(4, 2), t + Vector2i(5, 2)]
	var path_out_a: Array = [t + Vector2i(8, 0), t + Vector2i(9, 0), t + Vector2i(10, 0), t + Vector2i(11, 0)]
	var path_out_b: Array = [t + Vector2i(8, 2), t + Vector2i(9, 2), t + Vector2i(9, 1)]
	for c: Vector2i in path_a + path_b + path_out_a + path_out_b:
		if sim.can_belt_cell_error(c) != "":
			return null
	if sim.buildings.placement_error("smelter", t + Vector2i(6, 0), false) != "" or sim.buildings.placement_error("smelter", t + Vector2i(6, 2), false) != "" \
			or sim.buildings.placement_error("storage_in", t + Vector2i(12, 0), false) != "":
		return null
	if sim.buildings.placement_error("miner", t, false) != "" or sim.place_building("miner", t) == null:
		return null
	if sim.place_building("smelter", t + Vector2i(6, 0)) == null or sim.place_building("smelter", t + Vector2i(6, 2)) == null:
		return null
	sim.place_building("storage_in", t + Vector2i(12, 0))
	sim.place_belt(path_a, 1)
	sim.place_belt(path_b, 1)
	sim.place_belt(path_out_a, 1)
	sim.place_belt(path_out_b, 0)
	var ok := bool(sim.call("place_belt_node", 1, t + Vector2i(4, 0), 1))  # splitter_basic feeds smelter A (front) and B (right)
	ok = bool(sim.call("place_belt_node", 4, t + Vector2i(9, 0), 1)) and ok  # merger joins both smelter outputs
	r["l2_nodes"] = int(r.get("l2_nodes", 0)) + (2 if ok else 0)
	return t


static func _l2_power(sim: Simulation, t: Vector2i, r: Dictionary) -> void:
	if sim.has_meta("qa_l2_power"):
		return
	sim.set_meta("qa_l2_power", true)
	var n := 0
	for off: Vector2i in [Vector2i(2, -2), Vector2i(7, -2), Vector2i(7, 4), Vector2i(10, 4)]:
		if sim.place_building("power_pole", t + off) != null:
			n += 1
	if sim.place_building("coal_generator", Scen.find_spot(sim, "coal_generator", t + Vector2i(1, -5), 0)) != null:
		n += 1
	r["l2_power"] = n
# endregion
