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
