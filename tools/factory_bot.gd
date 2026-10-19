extends RefCounted
## U4: "real production" bot. Builds a factory ONLY through public Simulation commands
## (place_building blueprints that colonists haul+build, place_belt, add_bill, set_research, deliver_*):
## no place_instant / buildings.place, no item spawning, no ledger writes. Deterministic (sim.rng only).
## Base: the tutorial bot + bot_report upkeep (as petition_bot/shuttle_bot) run first; this adds the factory.
## Lines: miner -> belt -> [smelter] -> belt -> storage_in at the hub (colonists haul the rest);
## assemblers/workbench are hand-fed by colonists from the stockpile; coal generators + pole chains.
## Experiment switch `assume_nitrogen` (OFF by default) scripts a nitrogen trickle because the home map has no vents.
const Bot := preload("res://tests/qa_tutorial_bot.gd")
const Scen := preload("res://tests/scenario.gd")
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Build order, one blueprint batch at a time: ["line", resource, smelt?] = miner(+smelter)+belts+storage_in at the hub,
## ["miner"] = hand-hauled essence miner (no belt, works before Conveyance), plus single machines.
const PLAN: Array = [
	["workbench"], ["miner"], ["refinery"], ["miner"], ["miner"], ["line", "iron_ore", true], ["line", "copper_ore", true], ["assembler"], ["terminal"], ["miner", "coal"], ["miner", "nitrogen"], ["line", "essence_ore", false],
	["gen"], ["line", "iron_ore", true], ["assembler"], ["workbench"], ["line", "copper_ore", true],
	["line", "iron_ore", true], ["gen"], ["assembler"], ["line", "iron_ore", true],
]
## tech -> first PLAN step at which it is queued (bench time and essence are not wasted early).
const RESEARCH: Dictionary = {"conveyance": 0, "assembly": 0, "filters": 0, "electrification": 5, "fortification": 9, "decoys_1": 9}  # D3: decoys_1 = ash beacon (burns waste)

var sim: Simulation
var base: Bot
var cap_percent := 50
var plate_target := 45
var compactors := 4  # PL: waste items bleed pollution; sinks stand right after the refinery
var plate_reserve := 12  # D3: fuel cells / extra bills never take the stock below this once an assembler is planned
var assume_nitrogen := false
var _step_fails := 0
var _stock_extra := 0
var _held := false
var max_pending := 3  # PG: knob pg_bot.max_pending overrides in _init
var _stock_grown := false
var _failed_step := -1
var _step := 0  ## index into _plan (PLAN plus PG knob insertions)
var _plan: Array = []
var _hub := Vector2i.ZERO
var _used_nodes: Dictionary = {}
var _routes: Array = []  ## pending belt jobs {from, to, dir}
var _supplied_day := 0
var phase_day: Array = [-1.0, -1.0, -1.0, -1.0]
var audit_day := -1.0
var launch_day := -1.0
var won_day := -1.0
var min_hp := 100
var gantry_started := false
var log: Array[String] = []
var _mine: Array[Vector2i] = []


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	base = Bot.new(sim)
	_hub = sim.map_center() + Vector2i(-2, 9)
	max_pending = _knob("max_pending", max_pending)
	_plan = PLAN.duplicate(true)
	for i in _knob("extra_miners", 0):
		_plan.insert(5, ["miner"])  # PG: ore (stock 0 for most of the first 25 days) gates construction, refining and research


## One bot step (call every Bot.STEP_TICKS ticks, then sim.run_ticks).
func act() -> void:
	_research()  # PG: before the tutorial bot, which otherwise starts the 3300-tick decoys chain ahead of conveyance
	base._act()
	if not _stock_grown and sim.tick >= 600:  # PL: the tutorial stockpile is 2x2 = 4 stacks; ore, ingots, plates, coal... filled it and haulers idled
		_stock_grown = true
		var spot := Scen.find_zone_spot(sim, sim.map_center() + Vector2i(-8, 6), Vector2i(6, 4))
		for y in 4:
			for x in 6:
				sim.set_zone(spot + Vector2i(x, y), "stockpile")
	if _stock_extra < _knob("stock_blocks", 2) and sim.day() >= 14 + 14 * _stock_extra and sim.tick % sim.ticks_per_day == 0:
		_stock_extra += 1  # PG: ore stacks filled the 6x4 stockpile, so coal / nitrogen / plates / parts from new machines had no cell to go to
		var spot2 := Scen.find_zone_spot(sim, sim.map_center() + Vector2i(-8 + 7 * _stock_extra, 11), Vector2i(6, 4))
		for y in 4:
			for x in 6:
				sim.set_zone(spot2 + Vector2i(x, y), "depot")
	if sim.tick % 20 == 0:
		_upkeep()
	_research()
	if sim.tick % 600 == 300:
		_priorities()
	if sim.tick % 200 == 0:
		_bills()
	_retry_routes()
	if sim.buildings.count_of("refinery") > 0 and sim.research.is_done("drilling"):
		_build()
	elif sim.tick % 100 == 0 and sim.research.is_done("drilling") and _bp_count("refinery") == 0 and _step >= 2:
		_hub_place("refinery", Vector2i(-4, 2))  # YX: a raid took the refinery; a player rebuilds it, the bot used to freeze
	if sim.tick % 600 == 0:
		_deliveries()
	if sim.tick % 100 == 0:
		_shuttle()
	if assume_nitrogen:
		_nitrogen_trickle()


func after() -> void:
	base._poll()


# --- attentive-player upkeep (bot_report's, minus its instant turret placement) ---------------------

func _upkeep() -> void:
	for p in sim.crises.pending.duplicate():
		var id := str(p["id"])
		sim.resolve_crisis(id, str(sim.crises.crises[id]["default_option"]))
	# Turrets as blueprints (10 refined each, built by colonists): 3 + waves, max 10.
	var have := sim.buildings.count_of("turret") + _bp_count("turret")
	var want := mini(3 + sim.threats.wave_index, 10)
	var turret_floor := 10 + (_research_reserve() if (have >= _knob("turret_min", 3) and _knob("turret_after_research", 1) == 1) else 0)  # PG: research essence before the 4th+ turret
	if have < want and sim.items.count_stored("refined_essence") >= turret_floor and _bp_count("turret") < 2:
		var angle := TAU * float(have * 7 % 13) / 13.0
		var near := sim.map_center() + Vector2i(roundi(cos(angle) * 5.0), roundi(sin(angle) * 5.0))
		var tc := _spot("turret", near, false)
		if tc.x >= 0:
			sim.place_building("turret", tc)
	# D3: debt first (unpaid debt -> despair -> escapes): refined goes to the debt item before turrets/contracts/research,
	# keeping a floor of one turret's cost; the earliest due tranche is paid every upkeep, long before the due day.
	var floor_keep := 10 if have < want else 0
	var debt_stock := sim.items.count_stored("refined_essence") - floor_keep - 3 - _research_reserve()  # PL: research essence first, debt drained the stock to 3 for 18 days
	var target: Colonist = null
	for c in sim.colonists.list:
		if not c.alive:
			continue
		var st := sim.debt.state_of(c)
		if st == null:
			continue
		if st.pending_choice:
			sim.choose_payoff(c.id, true)
		elif st.remaining() > 0 and (target == null or st.period_paid < sim.debt.state_of(target).period_paid):
			target = c
	# DB: installments are paid before any other refined use (missing one feeds despair -> escapes); the rest is the optional extra above.
	var inst := int(sim.defs.debt["installment"])
	for c in sim.colonists.list:
		var ist := sim.debt.state_of(c) if c.alive else null
		if ist != null and ist.remaining() > 0 and ist.period_paid < inst and sim.day() >= ist.due_day - 6:
			var avail := sim.items.count_stored("refined_essence") - 2 - floor_keep  # PX: turrets outrank an installment (grace period covers a miss)
			if avail > 0:
				sim.pay_debt(c.id, mini(mini(avail, inst - ist.period_paid), ist.remaining()))
	debt_stock = sim.items.count_stored("refined_essence") - floor_keep - 3 - _research_reserve()
	if target != null and debt_stock > 0:
		sim.pay_debt(target.id, mini(debt_stock, sim.debt.state_of(target).remaining()))
	var reserve := maxi(0, want - have) * 10
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
	_beacon()
	if sim.tick % sim.ticks_per_day == 0:
		for c in sim.colonists.list:
			if c.alive:
				for sk: String in c.skills.levels:
					if sim.perks.points_available(c, sk) > 0:
						for pid in sim.perks.perks_of_skill(sk):
							if sim.learn_perk(c.id, pid):
								break


## PL: essence still owed to the factory techs (filters / assembly / electrification) that are not queued-and-paid yet.
func _research_reserve() -> int:
	var n := 0
	for t: String in RESEARCH:
		if sim.research.is_done(t) or sim.research.paid.has(t) or not sim.defs.research.has(t) or t in ["fortification", "decoys_1"] or (t == "electrification" and _knob("gens", 1) == 0):
			continue
		n += int(sim.defs.research[t]["cost"]["essence"])
	return n


## Crew management: two researchers (the tutorial bot's choice), two farmers, the rest build, haul and mine.
func _priorities() -> void:
	var i := 0
	for c in sim.colonists.list:
		if not c.alive:
			continue
		if i == 2 or i == 3:  # farmers: food was the first thing to fail when everybody built
			sim.set_work_priority(c.id, "growing", 1)
			sim.set_work_priority(c.id, "cooking", 1)
		elif i >= 4:
			sim.set_work_priority(c.id, "construction", 1)  # PL: builds were starved behind mining (refinery took d13-d30)
			sim.set_work_priority(c.id, "hauling", 1)
			sim.set_work_priority(c.id, "mining", 3)
			sim.set_work_priority(c.id, "repair", 1)  # YX: repair/operating default to 3 and starved behind endless hauling/building
			sim.set_work_priority(c.id, "operating", 1)
		i += 1


## Machines break from wear and every repair costs plates (balance machine_repair_cost), so the workbench
## hammers a small plate stock from essence ore (hand_plate) long before the assembler line exists.
func _bills() -> void:
	var wb := _first("workbench")
	if wb == null or not sim.defs.recipes.has("hand_plate"):
		return
	# YX: a small plate stock for repairs early; the audit-2 stockpile (plate_target) only once the assembler/power chain stands,
	# so the early essence ore goes to miners and smelters instead of 120 ore of hammered plates.
	var want := plate_target if (sim.buildings.count_of("coal_generator") > 0 or _knob("gens", 1) == 0 and _step >= _knob("plate_step", 6)) else mini(plate_target, 8)  # PG: without generators the old test never opened the big plate bill
	if sim.milestones.is_tier_done(2):
		want = maxi(want, _knob("plate_p1", 90))  # P1 needs 60 plates + 20 parts (= 20 more plates)
	if _step >= 3:
		want = maxi(want, plate_reserve)  # D3: repair reserve once the assembler chain is planned
	for bill: Bill in sim.crafting.bills_of(wb):
		if bill.recipe_id == "hand_plate":
			if bill.target != want:
				sim.update_bill(wb.id, bill.id, "until", want, bill.paused)
			return
	sim.add_bill(wb.id, "hand_plate", "until", want)


func _has_bill(wb: Building, recipe_id: String) -> bool:
	for bill: Bill in sim.crafting.bills_of(wb):
		if bill.recipe_id == recipe_id:
			return true
	return false


# --- research / taint cap ------------------------------------------------------------------------

func _research() -> void:
	if sim.buildings.count_of("research_bench") == 0:
		return
	for t: String in RESEARCH:
		if t == "filters" and _knob("asm_first", 1) == 1 and not (sim.research.is_done("assembly") or sim.research.queue.has("assembly")):
			continue  # PG: assembly (20 essence) gates parts/audit; filters (10) used to grab the first essence and delay it by 4 days
		if t == "electrification" and _knob("gens", 1) == 0:
			continue  # PG: no generators -> no power research (2400 bench ticks) and no 50% unpowered penalty
		if _step >= int(RESEARCH[t]) and (t == "conveyance" or sim.research.is_done("conveyance")) and not sim.research.is_done(t) and not sim.research.queue.has(t):
			sim.queue_research(t, true)
	# PG: the tutorial bot's free decoys chain (3300 bench ticks) sits at the queue front and delays conveyance -> assembly by ~4 days;
	# move whatever precedes the next factory tech behind it (progress is kept).
	for t in ["conveyance", "assembly", "filters"]:
		var qi: int = sim.research.queue.find(t)
		if qi > 0 and sim.research.lock_reason(t) == "":
			var ahead: Array = sim.research.queue.slice(0, qi)
			for a: String in ahead:
				sim.queue_research(a, false)
			for a: String in ahead:
				sim.queue_research(a, true)
			break
	# PG: the refinery eats every loose ore stack, so blueprints (which take ore from STORAGE only) waited for days with colonists asleep.
	# Keep exactly what the open blueprints still miss (+ a small base) in the stockpile; the rest flows on to the refinery.
	var base_res := _knob("ore_reserve", 0)
	var early := sim.buildings.count_of("miner") < _knob("reserve_miners", 3) and sim.day() < _knob("reserve_day", 14)
	if base_res > 0 and not early and sim.is_rule_on("ore_reserve"):
		sim.set_rule("ore_reserve", false)  # first miners stand: ore flows to the refinery again
	if base_res > 0 and early:
		var need := base_res
		for bp in sim.buildings.blueprints:
			need += bp.missing("essence_ore")
		sim.defs.rules["ore_reserve"]["amount"] = mini(need, _knob("ore_reserve_max", 120))
		if not sim.is_rule_on("ore_reserve"):
			sim.set_rule("ore_reserve", true)
	if sim.research.is_done("filters") and not sim.is_rule_on("refine_cap"):
		sim.defs.rules["refine_cap"]["max_contamination_percent"] = cap_percent  # the S5 cap level
		sim.set_rule("refine_cap", true)


# --- building ------------------------------------------------------------------------------------

## place_building that remembers the cell (the gate below waits only for the bot's own blueprints).
func _put(def_id: String, c: Vector2i) -> Blueprint:
	var bp := sim.place_building(def_id, c)
	if bp != null:
		_mine.append(c)
	return bp


func _pending() -> bool:
	var left: Array[Vector2i] = []
	for c in _mine:
		if sim.buildings.blueprint_at(c) != null:
			left.append(c)
	_mine = left
	return not _mine.is_empty()


## The tutorial bot's chain helper (Scenario.build_chain, blueprint mode) returns {} even on success, so the bot
## keeps placing chains on every node: 7 miner/smelter/storage trios that only soak up ore. A player would cancel
## the extras; keep the first (lowest id) blueprint of each type, cancel unstarted foreign ones.
func _cancel_orphans() -> void:
	var kept := {}
	for bp in sim.buildings.blueprints.duplicate():
		if not (bp.def_id in ["miner", "smelter", "storage_in"]) or _mine.has(bp.cell):
			continue
		if not kept.has(bp.def_id):
			kept[bp.def_id] = true
		elif bp.delivered_total() == 0:
			sim.deconstruct(bp.cell)


func _build() -> void:
	_cancel_orphans()
	_pending()
	if _mine.size() >= max_pending or _step >= _plan.size() or not _routes.is_empty():  # PL: several blueprints at once (one at a time took 8-10 days per step)
		return
	var s: Array = _plan[_step]
	var ok := false
	match str(s[0]):
		"miner":
			ok = _ore_miner(str(s[1]) if s.size() > 1 else "essence_ore")
		"line":
			if not sim.research.is_done("conveyance"):
				return
			ok = _line(str(s[1]), bool(s[2]))
		"terminal":
			ok = _hub_place("warden_terminal", Vector2i(-3, 3))
		"gen":
			ok = true if _knob("gens", 1) == 0 else (sim.research.is_done("electrification") and _gen())  # PG: poles/generators switch the power system on (unpowered = 50%)
		"assembler":
			ok = sim.research.is_done("assembly") and _hub_place("assembler", Vector2i(0, 0))
		"workbench":
			ok = sim.buildings.count_of("workbench") + _bp_count("workbench") > (0 if _step < 3 else 1) or _hub_place("workbench", Vector2i(2, 4))
		"refinery":
			ok = sim.buildings.count_of("refinery") + _bp_count("refinery") > 0 or _hub_place("refinery", Vector2i(-4, 2))  # PL: the tutorial bot already built one; a second cost 15 ore and 10+ days
	if ok:
		if str(s[0]) == "assembler" and not log.any(func(l: String) -> bool: return l.ends_with("built [\"assembler\"]")):
			log.append("assembler chain d%.1f" % _day_f())
		_step += 1
		_step_fails = 0
		log.append("d%.1f built %s" % [float(sim.tick) / sim.ticks_per_day, str(s)])
	else:
		if str(s[0]) == "miner" or (str(s[0]) == "line" and sim.research.is_done("conveyance")):
			_step_fails += 1
		if _step_fails > (_knob("miner_fails", 5) if str(s[0]) == "miner" else _knob("line_fails", 60)) and str(s[0]) in ["miner", "line"]:  # PL: a step that cannot be placed for ~40 tries is skipped, not waited on forever
			_step += 1
			_step_fails = 0
			return
	if not ok and _failed_step != _step:
		_failed_step = _step
		log.append("d%.1f step %d %s waiting (placement/research)" % [float(sim.tick) / sim.ticks_per_day, _step, str(s)])


## Nearest free spot of `def_id` around hub+off; machines also need their port cells free.
func _spot(def_id: String, near: Vector2i, ports_free := true) -> Vector2i:
	var blocked := _port_cells()
	for r in range(0, 26):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var c := near + Vector2i(x, y)
				if sim.buildings.placement_error(def_id, c, false) != "":
					continue
				if ports_free and not _ports_ok(def_id, c, blocked):
					continue
				return c
	return Vector2i(-1, -1)


func _hub_place(def_id: String, off: Vector2i) -> bool:
	var c := _spot(def_id, _hub + off, false)
	if c.x < 0:
		return false
	var bp := _put(def_id, c)
	if bp == null:
		return false
	_power(c)
	return true


func _ports(def_id: String, c: Vector2i) -> Array:
	var out: Array = []
	for p: Dictionary in sim.defs.buildings[def_id].get("ports", []):
		out.append({"cell": c + Vector2i(int(p["dx"]), int(p["dy"])), "kind": str(p["kind"])})
	return out


func _port_cells() -> Dictionary:
	var d := {}
	for b in sim.buildings.list:
		for p in _ports(b.def_id, b.cell):
			d[p["cell"]] = true
	for bp in sim.buildings.blueprints:
		for p in _ports(bp.def_id, bp.cell):
			d[p["cell"]] = true
	return d


func _ports_ok(def_id: String, c: Vector2i, blocked: Dictionary) -> bool:
	var size: Array = sim.defs.buildings[def_id]["size"]
	for p in _ports(def_id, c):
		var pc: Vector2i = p["cell"]
		if blocked.has(pc) or not _belt_free(pc):
			return false
		# the port belt must not sit inside this machine's own footprint
		if pc.x >= c.x and pc.y >= c.y and pc.x < c.x + int(size[0]) and pc.y < c.y + int(size[1]):
			return false
	return true


func _belt_free(c: Vector2i) -> bool:
	return sim.map.in_bounds(c) and sim.can_belt_cell_error(c) == "" and sim.logistics.belt_dir(c) < 0


## Essence miner without belts: colonists haul its output buffer to the stockpile (works from day 2).
func _ore_miner(res := "essence_ore") -> bool:
	var cands: Array[Vector2i] = []
	for n in sim.map.node_cells():
		if sim.map.node_resource(n) == res and not _used_nodes.has(n):
			cands.append(n)
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(sim.map_center()) < b.distance_squared_to(sim.map_center()))
	# PG: spots whose anchor cell is plain ground first: a machine anchored on a deposit cell is "unreachable" for the hauler, its output never leaves
	var spots: Array[Vector2i] = []
	for n in cands:
		for t: Vector2i in [n, n + Vector2i(-1, 0), n + Vector2i(0, -1), n + Vector2i(-1, -1)]:
			spots.append(t)
	var ground: Array[Vector2i] = spots.filter(func(t: Vector2i) -> bool: return sim.map.is_passable(t))
	var rest: Array[Vector2i] = spots.filter(func(t: Vector2i) -> bool: return not sim.map.is_passable(t))
	for t: Vector2i in (ground + rest if res != "essence_ore" else spots):  # essence miners keep the old order (changing it shifted every raid timeline)
		if sim.buildings.placement_error("miner", t, false) != "":
			continue
		var pure := true
		for yy in 2:
			for xx in 2:
				var p := t + Vector2i(xx, yy)
				if sim.map.is_node(p) and sim.map.node_resource(p) != res:
					pure = false
		if pure and _put("miner", t) != null:
			for yy in 2:
				for xx in 2:
					_used_nodes[t + Vector2i(xx, yy)] = true
			return true
	return false


## PG: a deposit inside rock (seeds 4/6/9) has no placeable 2x2 miner spot (rock cannot be dug). Colonists can still hand-mine
## the nodes: designate them, and a smelter at the hub gets the ore hauled in (hauler feed) and the ingots hauled out.
func _hand_mine(res: String, smelt: bool) -> bool:
	var cells: Array[Vector2i] = []
	for n in sim.map.node_cells():
		if sim.map.node_resource(n) == res and not _used_nodes.has(n):
			cells.append(n)
	if cells.is_empty():
		return false
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(_hub) < b.distance_squared_to(_hub))
	var first := cells[0]
	var n_marked := 0
	for c in cells:
		if c.distance_squared_to(first) <= 100 and n_marked < 4:
			sim.designate_mine(c, true)
			_used_nodes[c] = true
			n_marked += 1
	if smelt:
		var sc := _spot("smelter", _hub + Vector2i(-3, -2), false)
		if sc.x < 0 or _put("smelter", sc) == null:
			return false
		_power(sc)
	log.append("d%.1f hand-mining %d %s nodes (no free 2x2 spot)" % [_day_f(), n_marked, res])
	return true


## Miner (+ optional smelter) on the nearest unused node of `res`, belts to a storage_in at the hub.
func _line(res: String, smelt: bool) -> bool:
	if smelt and not sim.research.is_done("smelting"):
		return false
	var cands: Array[Vector2i] = []
	for n in sim.map.node_cells():
		if sim.map.node_resource(n) == res and not _used_nodes.has(n):
			cands.append(n)
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(_hub) < b.distance_squared_to(_hub))
	var blocked := _port_cells()
	var miner_at := Vector2i(-1, -1)
	for n in cands:
		for t: Vector2i in [n, n + Vector2i(-1, 0), n + Vector2i(0, -1), n + Vector2i(-1, -1)]:
			if sim.buildings.placement_error("miner", t, false) != "" or not _ports_ok("miner", t, blocked):
				continue
			var pure := true
			for yy in 2:
				for xx in 2:
					var p := t + Vector2i(xx, yy)
					if sim.map.is_node(p) and sim.map.node_resource(p) != res:
						pure = false
			if pure:
				miner_at = t
				break
		if miner_at.x >= 0:
			break
	if miner_at.x < 0:
		if _hand_mine(res, smelt):
			return true
		log.append("no node for %s" % res)
		return false
	var proc_at := Vector2i(-1, -1)
	if smelt:
		proc_at = _spot("smelter", miner_at + Vector2i(4, 0), true)  # PL: smelter beside the miner, colonists haul the ingots (long belts kept failing)
	var store_at := Vector2i(-1, -1) if smelt else _spot("storage_in", _hub + Vector2i(_step * 2 % 12 - 6, 5), true)
	if (smelt and proc_at.x < 0) or (not smelt and store_at.x < 0):
		return false
	if _put("miner", miner_at) == null:
		return false
	for yy in 2:
		for xx in 2:
			_used_nodes[miner_at + Vector2i(xx, yy)] = true  # PL: mark only after the line is really placed (a failed smelter spot used to burn the node)
	_power(miner_at)
	if smelt:
		_put("smelter", proc_at)
		_power(proc_at)
	if not smelt:
		_put("storage_in", store_at)
	var mo: Vector2i = _ports("miner", miner_at)[0]["cell"]
	if smelt:
		var si: Vector2i = _ports("smelter", proc_at)[0]["cell"]
		_routes.append({"from": mo, "to": si, "into": proc_at, "size": 2})
	else:
		var di2: Vector2i = _ports("storage_in", store_at)[0]["cell"]
		_routes.append({"from": mo, "to": di2, "into": store_at, "size": 1})
	_retry_routes()
	return true


func _retry_routes() -> void:
	var left: Array = []
	for r: Dictionary in _routes:
		if not _lay(r):
			r["tries"] = int(r.get("tries", 0)) + 1
			if int(r["tries"]) < 30:  # keep trying: blueprints change what is free
				left.append(r)
			else:
				log.append("route abandoned %s" % str(r["from"]))
	_routes = left


## BFS over free belt cells from `from` to `to`; last belt points into the building at `into`.
func _lay(r: Dictionary) -> bool:
	var src: Vector2i = r["from"]
	var dst: Vector2i = r["to"]
	if not _belt_free(src) or not _belt_free(dst):
		return false
	var blocked := _port_cells()
	blocked.erase(src)
	blocked.erase(dst)
	var prev := {src: src}
	var q: Array[Vector2i] = [src]
	var head := 0
	var found := false
	while head < q.size() and q.size() < 6000:
		var c := q[head]
		head += 1
		if c == dst:
			found = true
			break
		for d in DIRS:
			var n := c + d
			if prev.has(n) or blocked.has(n) or not _belt_free(n):
				continue
			prev[n] = c
			q.append(n)
	if not found:
		return false
	var path: Array = [dst]
	while path[0] != src:
		path.push_front(prev[path[0]])
	var into: Vector2i = r["into"]
	var sz := int(r["size"])
	var last := -1
	for i in 4:
		var t: Vector2i = dst + DIRS[i]
		if t.x >= into.x and t.y >= into.y and t.x < into.x + sz and t.y < into.y + sz:
			last = i
	return last >= 0 and sim.place_belt(path, last)


func _gen() -> bool:
	var c := _spot("coal_generator", _hub + Vector2i(6 + 3 * sim.buildings.count_of("coal_generator"), 4), true)
	if c.x < 0:
		return false
	if _put("coal_generator", c) == null:
		return false
	_power(c)
	if sim.buildings.count_of("power_pole") + _bp_count("power_pole") == 0:
		_hub_place("power_pole", Vector2i(4, 4))
	return true


## PG: experiment knobs from balance.json "pg_bot" (so factory_eval --ov can A/B them without code edits).
func _knob(k: String, dflt: int) -> int:
	return int(sim.defs.balance.get("pg_bot", {}).get(k, dflt))


func _bp_count(def_id: String) -> int:
	var n := 0
	for bp in sim.buildings.blueprints:
		if bp.def_id == def_id:
			n += 1
	return n


## Pole chain (a pole every ~5 cells) from the nearest pole/generator to a machine at `cell`.
func _power(cell: Vector2i) -> void:
	if not sim.research.is_done("electrification"):
		return
	var poles: Array[Vector2i] = []
	for b in sim.buildings.list:
		if b.def_id == "power_pole" or b.def_id == "coal_generator":
			poles.append(b.cell)
	for bp in sim.buildings.blueprints:
		if bp.def_id == "power_pole" or bp.def_id == "coal_generator":
			poles.append(bp.cell)
	if poles.is_empty():
		return
	for guard in 12:
		var best := poles[0]
		for p in poles:
			if (p - cell).length_squared() < (best - cell).length_squared():
				best = p
		var dist := (best - cell).length()
		if dist <= 5.0:
			return
		var step := Vector2(cell - best).normalized() * 5.0
		var want := best + Vector2i(roundi(step.x), roundi(step.y))
		var spot := _spot("power_pole", want, false)
		if spot.x < 0 or _put("power_pole", spot) == null:
			return
		poles.append(spot)


## D3: one ash beacon to burn waste (existing sink) once decoys_1 is researched; if D2's `waste_sink_early` flag exists, it is read
## (the bot works the same with the flag off: the 50% taint cap rule is already on).
func _beacon() -> void:
	if sim.buildings.count_of("miner") < _knob("sink_after_miners", 3) and sim.day() < 14:
		return  # PG: compactors/beacons (ore each) competed with the first miners for the scarce ore; pollution is still ~0 then
	if sim.tick % 120 == 60 and sim.buildings.count_of("refinery") > 0 and bool(sim.defs.balance.get("waste_sink_early", false)) and sim.defs.buildings.has("waste_compactor"):
		var have := sim.buildings.count_of("waste_compactor") + _bp_count("waste_compactor")
		if have < compactors and _bp_count("waste_compactor") == 0:
			var cc := _spot("waste_compactor", sim.map_center() + Vector2i(-3 + have * 2, 4), false)
			if cc.x >= 0 and sim.place_building("waste_compactor", cc) != null:
				log.append("d%.1f built waste_compactor" % _day_f())
	if sim.tick % 200 != 0 or not sim.research.is_done("decoys_1"):
		return
	if sim.buildings.count_of("ash_beacon") + _bp_count("ash_beacon") >= 1:
		return
	if sim.items.count_stored("essence_ore") < 12 and not bool(sim.defs.balance.get("waste_sink_early", false)):
		return
	var c := _spot("ash_beacon", sim.map_center() + Vector2i(3, 3), false)
	if c.x >= 0 and sim.place_building("ash_beacon", c) != null:
		log.append("d%.1f built ash_beacon" % _day_f())


# --- petitions / shuttle -------------------------------------------------------------------------

func _deliveries() -> void:
	var day := float(sim.tick) / sim.ticks_per_day
	if not sim.milestones.is_tier_done(2):
		if sim.milestones.has_terminal() and sim.deliver_audit(2):
			audit_day = day
		return
	var p: int = sim.petition.next_phase()
	_hold_ingots(p == 2)
	if p > 0 and sim.deliver_petition(p):
		phase_day[p - 1] = day


## PG: petition II needs 20 iron + 20 copper INGOTS in storage, but the assemblers turn every ingot into plates/parts
## (stock stayed 0 on every seed). While phase II is open the recipes' stock caps stop them (a player pauses the bills).
func _hold_ingots(on: bool) -> void:
	if on == _held:
		return
	_held = on
	if sim.defs.recipes.has("make_plate"):
		if on:
			sim.defs.recipes["make_plate"]["stock_cap"] = {"plate": 1}
		else:
			sim.defs.recipes["make_plate"].erase("stock_cap")
	if sim.defs.recipes.has("make_parts"):
		sim.defs.recipes["make_parts"]["stock_cap"] = {"parts": 1} if on else {"parts": 25}


func _shuttle() -> void:
	var st: Dictionary = sim.get_shuttle_state()
	var ph := str(st.get("phase", ""))
	var day := float(sim.tick) / sim.ticks_per_day
	if ph == "building" or ph == "ready":
		if not gantry_started and sim.shuttle.gantry() == null and not _pending() and _step >= _plan.size():
			var c := _spot("release_gantry", sim.map_center() + Vector2i(-12, -8), false)
			if c.x >= 0 and _put("release_gantry", c) != null:
				gantry_started = true
				_power(c)
				for off in [Vector2i(-2, -2), Vector2i(5, -2), Vector2i(-2, 5), Vector2i(5, 5)]:
					var tc := _spot("turret", c + off, false)
					if tc.x >= 0:
						_put("turret", tc)
		if sim.shuttle.gantry() != null:
			if sim.tick % 600 == 0:
				sim.deliver_shuttle_parts()
			var wb := _first("workbench")
			if wb != null and not _has_bill(wb, "fuel_cell") and sim.defs.recipes.has("fuel_cell") and int(st.get("parts", 0)) >= int(st.get("need", 24)) and sim.items.count_stored("plate") >= plate_reserve + 4:  # D3: parts first, plates keep a repair reserve
				sim.add_bill(wb.id, "fuel_cell", "until", 8)
	if ph == "ready" and sim.launch_shuttle():
		launch_day = day
	if ph == "countdown":
		min_hp = mini(min_hp, int(st["hp"]) * 100 / maxi(1, int(st["max_hp"])))
		if int(st["hp"]) < int(st["max_hp"]) * 7 / 10:
			sim.repair_gantry()
	if ph == "won" and won_day < 0.0:
		won_day = day


func _first(def_id: String) -> Building:
	for b in sim.buildings.list:
		if b.def_id == def_id:
			return b
	return null


## EXPERIMENT ONLY (assume_nitrogen): the home map has no vents node; 3/day from d10, like the old scripted bots.
func _nitrogen_trickle() -> void:
	var d := sim.day()
	while _supplied_day < d:
		_supplied_day += 1
		if _supplied_day >= 10:
			sim.ledger.record_produced("nitrogen", 3, "bot_supply")
			sim.items.drop(sim.map_center() + Vector2i(5, 1), "nitrogen", 3)


# --- reporting -----------------------------------------------------------------------------------

## What stops the next milestone, e.g. "P3: nitrogen 0/20".
func blocker() -> String:
	if not sim.milestones.is_tier_done(2):
		var rem: Dictionary = sim.milestones.remaining(2)
		return "audit2: " + _fmt_missing(rem)
	var p: int = sim.petition.next_phase()
	if p > 0:
		return "P%d: %s" % [p, _fmt_missing(sim.petition.remaining(p))]
	var st: Dictionary = sim.get_shuttle_state()
	return "shuttle %s parts %d/%d" % [str(st.get("phase", "")), int(st.get("parts", 0)), int(st.get("need", 0))]


func _fmt_missing(rem: Dictionary) -> String:
	var out: Array[String] = []
	var keys := rem.keys()
	keys.sort()
	for k: String in keys:
		if int(rem[k]) > 0:
			out.append("%s -%d (stock %d)" % [k, int(rem[k]), sim.items.count_stored(k)])
	return ", ".join(out)


func _day_f() -> float:
	return float(sim.tick) / sim.ticks_per_day


## Plays one seed. opts: assume_nitrogen, cap. Returns the numbers the report prints.
static func play(seed_value: int, days: int, opts := {}, bus: Node = null) -> Dictionary:
	var own_bus := bus == null
	if own_bus:
		bus = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(seed_value, bus, null, {"tutorial": true, "research_locked": true})
	sim.start_new_game()
	var bot: RefCounted = (load("res://tools/factory_bot.gd") as GDScript).new(sim)
	bot.assume_nitrogen = bool(opts.get("assume_nitrogen", false))
	bot.cap_percent = int(opts.get("cap", 35))
	bot.plate_target = int(opts.get("plate", 45))
	var died_a: Array = [0]
	sim.bus.colonist_died.connect(func(_i: int) -> void: died_a[0] += 1)
	var limit := days * sim.ticks_per_day
	while sim.tick < limit and sim.game_over_reason == "":
		bot.act()
		for qp in sim.quests.pending.duplicate():  # region QX: the bot takes its preferred option (cheap, no plates), else the first enabled one
			var pref: String = {"q6_auditor": "tour", "pilgrims_of_the_slag": "silence", "q1": "ignore"}.get(str(qp["quest"]), "")
			for qo: Dictionary in qp["options"]:
				if bool(qo["enabled"]) and (pref == "" or qo["id"] == pref):
					sim.answer_quest(int(qp["uid"]), str(qo["id"]))
					break
		sim.run_ticks(Bot.STEP_TICKS)
		bot.after()
	var nit_nodes := 0
	for n in sim.map.node_cells():
		if sim.map.node_resource(n) == "nitrogen":
			nit_nodes += 1
	var st: Dictionary = sim.get_shuttle_state()
	var r := {
		"seed": seed_value, "phase_day": bot.phase_day.duplicate(), "audit_day": bot.audit_day,
		"parts": int(st.get("parts", 0)), "need": int(st.get("need", 24)), "launch_day": bot.launch_day, "won_day": bot.won_day,
		"phase": str(st.get("phase", "")), "min_hp": bot.min_hp,
		"gone": sim.debt.gone.size(), "alive": sim.colonists.alive_count(), "died": died_a[0], "pollution": sim.contamination.fraction() * 100.0,
		"food": sim.items.count_stored("raw_food") + sim.items.count_stored("meal"), "over": sim.game_over_reason,
		"debt_pct": sim.milestones.debt_paid_pct(), "end_day": sim.day(), "blocker": bot.blocker(), "nitrogen_nodes": nit_nodes,
		"built": {}, "steps": bot._step, "log": bot.log.duplicate(),
	}
	for b in sim.buildings.list:
		r["built"][b.def_id] = int(r["built"].get(b.def_id, 0)) + 1
	for item in ["plate", "parts", "ingot_iron", "ingot_copper", "coal", "refined_essence", "essence_ore", "fuel_cell"]:
		r["built"]["stock_" + item] = sim.items.count_stored(item)
	var led := {}
	for item in ["essence_ore", "refined_essence", "iron_ore", "ingot_iron", "copper_ore", "ingot_copper", "coal", "plate", "parts"]:
		led[item] = "%d/%d" % [int(sim.ledger.produced.get(item, 0)), int(sim.ledger.consumed.get(item, 0))]
	r["ledger"] = led
	# region D4
	var qs: Array = []
	for qid: String in sim.quests.quests:
		qs.append(qid)
	qs.sort()
	r["quests"] = qs  # region QX
	r["waste_prod"] = int(sim.ledger.produced.get("waste", 0))
	# endregion
	var power_f := 1.0
	if sim.power != null and sim.power.enabled:
		var w: Dictionary = sim.power.worst_net()
		if not w.is_empty():
			power_f = float(w["factor"])
	r["power_factor"] = power_f
	sim.dispose()
	if own_bus:
		bus.free()
	return r
