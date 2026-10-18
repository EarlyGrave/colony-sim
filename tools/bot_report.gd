extends SceneTree
## Headless "attentive player" bot: standard colony + farming + beds + workbench
## (essence rounds), accepts/delivers contracts when affordable, pays debt quotas,
## resolves crises with the default option, rebuilds turrets. Plays N days x seeds.
## godot --headless --path . -s tools/bot_report.gd [-- --days=25 --seeds=5 --verbose]

const Scenario := preload("res://tests/scenario.gd")
static var preset_id := ""  # region B1: difficulty preset for play() (tools/b1_preset_table.gd)


func _init() -> void:
	var days := 25
	var seeds := 5
	var verbose := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
		elif a == "--verbose":
			verbose = true
	var bus: Node = load("res://autoload/event_bus.gd").new()
	for seed_value in range(1, seeds + 1):
		var r := play(seed_value, days, bus)
		print(_format(r, verbose))
		for c in bus.get_signal_list():
			for conn in bus.get_signal_connection_list(c["name"]):
				bus.disconnect(c["name"], conn["callable"])
	bus.free()
	quit()


static func play(seed_value: int, days: int, bus: Node, profile := "baseline") -> Dictionary:
	var sim := Simulation.new(seed_value, bus, null, StartOpts.preset_opts(Defs.get_default(), preset_id) if preset_id != "" else {})  # region B1
	sim.start_new_game()
	Scenario.standard_colony(sim, 3)
	var center := sim.map_center()
	# Farming: growing patch; workbench with a standing ammo bill.
	var field := Scenario.find_zone_spot(sim, center + Vector2i(6, 6), Vector2i(3, 3))
	for y in 3:
		for x in 3:
			sim.set_zone(field + Vector2i(x, y), "growing")
	var bench := sim.buildings.place("workbench", Scenario.find_spot(sim, "workbench", center + Vector2i(-4, -4), 0), false)
	if bench != null:
		sim.add_bill(bench.id, "essence_rounds", "until", 20)
	var r := {
		"seed": seed_value, "cause": "alive", "end_day": days, "waves": 0,
		"contam": {}, "c_ok": 0, "c_fail": 0, "c_decl": 0, "debts_paid": 0, "riots": 0,
		"escapes": 0, "caught": 0, "idle": 0, "total": 0, "crises": [], "blooms": 0,
		"peak_anger": 0.0, "turrets_rebuilt": 0, "died": 0,
	}
	var blooms_seen: Dictionary = {}
	sim.bus.debt_paid.connect(func(_i: int) -> void: r["debts_paid"] += 1)
	sim.bus.riot_started.connect(func(_i: int) -> void: r["riots"] += 1)
	sim.bus.colonist_escaped.connect(func(_i: int) -> void: r["escapes"] += 1)
	sim.bus.escape_stopped.connect(func(_i: int) -> void: r["caught"] += 1)
	sim.bus.contract_fulfilled.connect(func(_i: int) -> void: r["c_ok"] += 1)
	sim.bus.contract_failed.connect(func(_i: int, _w: String) -> void: r["c_fail"] += 1)
	sim.bus.colonist_died.connect(func(_i: int) -> void: r["died"] += 1)
	sim.bus.crisis_started.connect(func(id: String, _t: String) -> void: r["crises"].append("%s@d%d" % [id, sim.day()]))
	var base_turrets := 3
	sim.bus.building_destroyed.connect(func(_i: int) -> void: r["lost_bld"] = int(r.get("lost_bld", 0)) + 1)  # region T5
	if "--trace" in OS.get_cmdline_user_args():
		sim.bus.wave_started.connect(func(i: int, s: float) -> void:
			print("  d%d wave %d str %.1f enemies %d turrets %d rounds %d refined %d" % [sim.day(), i, s, sim.threats.enemies.size(), sim.buildings.count_of("turret"), sim.items.count_stored("essence_rounds"), sim.items.count_stored("refined_essence")]))
		sim.bus.wave_ended.connect(func(i: int) -> void:
			var hq := 0.0
			for b in sim.buildings.list:
				if b.def_id == "hq":
					hq = b.hp
			print("  ended %d hq %.0f kills %d" % [i, hq, sim.threats.kills]))
	for i in sim.ticks_per_day * days:
		sim.step()
		if sim.game_over_reason != "":
			break
		if profile == "power" and sim.tick % 20 == 0 and sim.power != null and sim.power.enabled:  # region LX: power columns
			var w := sim.power.worst_net()
			if not w.is_empty():
				r["pw_samples"] = int(r.get("pw_samples", 0)) + 1
				r["pw_sup"] = float(r.get("pw_sup", 0.0)) + float(w["supply"])
				r["pw_dem"] = float(r.get("pw_dem", 0.0)) + float(w["demand"])
				if float(w["factor"]) < 0.9:
					r["pw_brown"] = int(r.get("pw_brown", 0)) + 1
		for c in sim.colonists.list:
			if c.alive and not c.hidden and not (c.health != null and c.health.downed):
				r["total"] += 1
				if c.job == null:
					r["idle"] += 1
		if "--trace" in OS.get_cmdline_user_args() and sim.tick % 40 == 0 and sim.threats.enemies.size() > 0:
			var hq2 := 0.0
			for b in sim.buildings.list:
				if b.def_id == "hq":
					hq2 = b.hp
			print("   t%d enemies %d hq %.0f turrets %d" % [sim.tick, sim.threats.enemies.size(), hq2, sim.buildings.count_of("turret")])
		if sim.tick % sim.ticks_per_day == 0:
			var d := sim.day()
			if d in [5, 10, 15, 20]:
				r["contam"][d] = sim.contamination.fraction() * 100.0
			r["peak_anger"] = maxf(r["peak_anger"], sim.contracts.anger)
			r["peak_pol"] = maxf(float(r.get("peak_pol", 0.0)), sim.contamination.fraction() * 100.0)  # region T5
		if sim.tick == sim.ticks_per_day:  # automation by day 4: more miners on the nodes, then miner + smelter
			if profile == "power":  # region LX: the splitter line gets the first pick of the ore nodes
				QaBot.l2_step(sim, r)
			Scenario.designate_nearest_deposits(sim, 16)
			r["chain"] = not Scenario.build_chain(sim, true).is_empty()
		if sim.tick % sim.ticks_per_day == 0:
			_t5_profile(sim, profile, r)  # region T5
		if sim.tick % 20 == 0:
			_act(sim, base_turrets, r)
			for cell: Vector2i in sim.mutation._blooms.keys():
				blooms_seen[cell] = true
	r["blooms"] = blooms_seen.size()
	r["kills"] = sim.threats.kills  # region T5
	r["belt_hp_lost"] = sim.logistics.belts.hp_lost_total  # region R3X
	r["repairs"] = sim.logistics.belts.repairs_total
	r["peak_pol"] = float(r.get("peak_pol", 0.0))  # region T5
	r["waves"] = sim.threats.wave_index
	r["end_day"] = sim.day()
	if sim.game_over_reason != "":
		r["cause"] = sim.game_over_reason
	r["c_decl"] = sim.contracts.open_contracts("refused").size()
	var pts: Array = []
	for c in sim.colonists.list:
		var n := 0
		for s: String in c.skills.levels:
			n += sim.perks.points_available(c, s) + sim.perks.spent(c, s)
		pts.append(n)
	r["points"] = pts
	r["colonists"] = sim.colonists.alive_count()
	r["anger"] = sim.contracts.anger
	r["refined"] = sim.buildings.refined_batches * int(sim.defs.recipes["refine_essence"]["outputs"]["refined_essence"])
	r["smelter_ok"] = sim.buildings.count_of("smelter") > 0 and sim.buildings.count_of("miner") > 0
	r["final_contam"] = sim.contamination.fraction() * 100.0
	sim.dispose()
	return r


static func _act(sim: Simulation, base_turrets: int, r: Dictionary) -> void:
	# Crises: pick the default option (the designer-intended "no thought" answer).
	for p in sim.crises.pending.duplicate():
		var id := str(p["id"])
		sim.resolve_crisis(id, str(sim.crises.crises[id]["default_option"]))
	# Turrets first (10 refined each): defence outranks quotas and debts.
	var want := mini(base_turrets + sim.threats.wave_index, 10)
	while sim.buildings.count_of("turret") < want:
		var angle := TAU * float(sim.buildings.count_of("turret") * 7 % 13) / 13.0
		var near := sim.map_center() + Vector2i(roundi(cos(angle) * 5.0), roundi(sin(angle) * 5.0))
		if sim.place_instant("turret", Scenario.find_spot(sim, "turret", near, 0)) == null:
			break
		r["turrets_rebuilt"] += 1
	var deficit := maxi(0, want - sim.buildings.count_of("turret"))
	var reserve := deficit * 10
	# Contracts: accept when stock covers it on top of active ones, deliver at once.
	var stock := sim.items.count_stored("refined_essence") - reserve
	var active_need := 0
	for c in sim.contracts.open_contracts("active"):
		active_need += int(c["essence"])
	for c in sim.contracts.open_contracts("offered"):
		if stock + 3 >= active_need + int(c["essence"]):
			if sim.accept_contract(int(c["id"])):
				active_need += int(c["essence"])
	for c in sim.contracts.open_contracts("active"):
		sim.deliver_contract(int(c["id"]))
	# Debt: pay the nearest-due prisoner from the surplus only; payoff choice = stay.
	var surplus := sim.items.count_stored("refined_essence") - reserve - active_need - 5
	var target: Colonist = null
	for c in sim.colonists.list:
		if not c.alive:
			continue
		var st := sim.debt.state_of(c)
		if st == null:
			continue
		if st.pending_choice:
			sim.choose_payoff(c.id, true)
		elif st.remaining() > 0 and (target == null or st.due_day < sim.debt.state_of(target).due_day):
			target = c
	if target != null and surplus > 0:
		sim.pay_debt(target.id, mini(surplus, sim.debt.state_of(target).remaining()))
	# Spend perk points on the first learnable perk of each skill.
	if sim.tick % sim.ticks_per_day == 0:
		for c in sim.colonists.list:
			if not c.alive:
				continue
			for s: String in c.skills.levels:
				if sim.perks.points_available(c, s) > 0:
					for pid in sim.perks.perks_of_skill(s):
						if sim.learn_perk(c.id, pid):
							break


static func _format(r: Dictionary, verbose: bool) -> String:
	var cm: Dictionary = r["contam"]
	var idle_pct: float = 100.0 * float(r["idle"]) / maxf(float(r["total"]), 1.0)
	var pts: Array = r["points"]
	var sum := 0
	for p: int in pts:
		sum += p
	var s := "seed %d: end day %d (%s) waves=%d colonists=%d(+%d died) contam%%@5/10/15/20=%s/%s/%s/%s final=%.0f refined=%d chain=%s contracts ok=%d fail=%d refused=%d anger=%.1f(peak %.1f) debts_paid=%d riots=%d escapes=%d caught=%d idle=%.0f%% perk_pts/col=%.1f crises=%s blooms=%d" % [
		r["seed"], r["end_day"], r["cause"], r["waves"], r["colonists"], r["died"],
		_f(cm.get(5)), _f(cm.get(10)), _f(cm.get(15)), _f(cm.get(20)), r["final_contam"], r["refined"], str(r["smelter_ok"]),
		r["c_ok"], r["c_fail"], r["c_decl"], r["anger"], r["peak_anger"], r["debts_paid"],
		r["riots"], r["escapes"], r["caught"], idle_pct, float(sum) / maxi(pts.size(), 1),
		str(r["crises"]), r["blooms"]]
	if verbose:
		s += " points=" + str(pts)
	return s


static func _f(v: Variant) -> String:
	return "-" if v == null else "%.0f" % v


# region T5
## QA play-styles (tools/qa_r3.gd). "automation": a new miner->smelter chain every day for days 2..6.
## "chip": automation plus slotting Warden Chips when the T4 chip system exists (stub until it merges).
static func _t5_profile(sim: Simulation, profile: String, r: Dictionary) -> void:
	if profile == "throttle" or profile == "mining":  # region B2: refine_cap bots (mining = cap at 0%, no refining)
		sim.defs.rules["refine_cap"]["max_contamination_percent"] = 0 if profile == "mining" else 50
		sim.set_rule("refine_cap", true)
		return
	if profile == "baseline":
		return
	if profile == "power":  # region L5: logistics-2 QA profile (automation chains + splitter line + poles + coal)
		QaBot.l2_step(sim, r)
	var d := sim.day()
	if d >= 2 and d <= 6:
		var center := sim.map_center()
		var nodes: Array[Vector2i] = []
		for c in sim.map.node_cells():
			if sim.map.node_resource(c) == "essence_ore":
				nodes.append(c)
		nodes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.distance_squared_to(center) < b.distance_squared_to(center) or (a.distance_squared_to(center) == b.distance_squared_to(center) and a < b))
		for n in nodes:
			if sim.place_building("miner", n) != null:
				r["chains"] = int(r.get("chains", 0)) + 1
				break
		if sim.place_building("smelter", Scenario.find_spot(sim, "smelter", center + Vector2i(-6 + d, -7), 0)) != null:
			r["chains"] = int(r.get("chains", 0)) + 1
	if profile == "chip" and sim.chips != null and d >= 3:  # R3X: real chips, granted free (tech + item)
		if not sim.research.done.has("ai_chips"):
			sim.research.done.append("ai_chips")
		for b in sim.buildings.list:
			if b.def_id in ["smelter", "assembler"] and not sim.chips.has_chip(b) and sim.chips.can_slot(b):
				sim.ledger.record_produced("ai_chip", 1, "qa")
				sim.items.drop(sim.map_center(), "ai_chip", 1)
				if sim.install_chip(b.id):
					r["chips"] = int(r.get("chips", 0)) + 1
# endregion
