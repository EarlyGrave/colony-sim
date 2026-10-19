extends TestCase
## Prisoner essence debt: assignment, payment, quota, payoff choice, despair,
## riot / escape breaks, save/load, determinism.


func _sim(seed_value := 5) -> Simulation:
	var d := peaceful_defs()
	d.mood["minor_chance"] = 1.0
	d.mood["extreme_chance"] = 1.0
	var sim := make_sim(seed_value, true, 24, 24, d)
	for i in 3:  # food, so long runs don't end in starvation
		var f := sim.map_center() + Vector2i(3 + i, 3)
		sim.set_zone(f, "stockpile")
		sim.ledger.record_produced("raw_food", 400, "test")
		sim.items.drop(f, "raw_food", 400)
	sim.run_ticks(1)  # starting colonists get their debt on the first tick
	return sim


func _stock(sim: Simulation, n: int) -> void:
	var at := sim.map_center() + Vector2i(3, 1)
	sim.set_zone(at, "stockpile")
	sim.ledger.record_produced("refined_essence", n, "test")
	sim.items.drop(at, "refined_essence", n)


func _despair(sim: Simulation, c: Colonist) -> void:
	sim.debt.state_of(c).despair = 90.0
	sim.mood.state_of(c).thoughts.append({"id": "x", "value": -60.0, "until": -1})
	sim.mood._recalc(c.mood)


func test_debt_assigned_deterministically() -> void:
	var a := _sim(7)
	var b := _sim(7)
	for i in a.colonists.list.size():
		var da := a.debt.state_of(a.colonists.list[i])
		var db := b.debt.state_of(b.colonists.list[i])
		assert_true(da != null)
		assert_eq(da.total, db.total)
		assert_true(da.total >= int(a.defs.debt["debt_min"]) and da.total <= int(a.defs.debt["debt_max"]))
	assert_eq(a.rng.randi(), b.rng.randi(), "main rng untouched by debt")


func test_arrival_gets_debt() -> void:
	var sim := _sim()
	var nc := ColonistGenerator.generate(sim, sim.map_center() + Vector2i(1, 1))
	sim.colonists.add(nc)
	assert_true(sim.debt.state_of(nc) != null)


func test_pay_reduces_debt_and_ledger() -> void:
	var sim := _sim()
	var c: Colonist = sim.colonists.list[0]
	var st := sim.debt.state_of(c)
	assert_false(sim.pay_debt(c.id, 10), "no stock")
	_stock(sim, 25)
	var before := st.remaining()
	assert_true(sim.pay_debt(c.id, 10))
	assert_eq(st.remaining(), before - 10)
	assert_eq(sim.ledger.get_count("debt:refined_essence"), 10)
	assert_eq(sim.ledger.balance_of("refined_essence"), sim.items.count_world("refined_essence"))
	assert_false(sim.pay_debt(c.id, 0))
	assert_eq(sim.command_log.back()[1], "pay_debt")


func test_quota_auto_pays_daily() -> void:
	var sim := _sim()
	var c: Colonist = sim.colonists.list[0]
	var st := sim.debt.state_of(c)
	_stock(sim, 100)
	assert_true(sim.set_quota(c.id, 4))
	sim.run_ticks(sim.ticks_per_day * 2 + 2)
	assert_eq(st.paid, 8)
	# Not enough stock: nothing is paid.
	var s2 := _sim(8)
	var c2: Colonist = s2.colonists.list[0]
	s2.set_quota(c2.id, 4)
	s2.run_ticks(s2.ticks_per_day + 2)
	assert_eq(s2.debt.state_of(c2).paid, 0)


func test_payoff_choice_stay_and_leave() -> void:
	var sim := _sim()
	var a: Colonist = sim.colonists.list[0]
	var b: Colonist = sim.colonists.list[1]
	_stock(sim, 100)
	sim.debt.state_of(a).total = 20  # DB: sentences are heavy; shrink them so the stock can pay
	sim.debt.state_of(b).total = 20
	var paid_ids: Array[int] = []
	sim.bus.debt_paid.connect(func(id: int) -> void: paid_ids.append(id))
	assert_false(sim.choose_payoff(a.id, true), "nothing to choose yet")
	sim.pay_debt(a.id, 999)
	sim.pay_debt(b.id, 999)
	assert_eq(paid_ids.size(), 2)
	var speed := float(a.bio.get("work_speed", 1.0))
	assert_true(sim.choose_payoff(a.id, true))
	assert_true(a.alive)
	assert_gt(float(a.bio["work_speed"]), speed)
	assert_true(sim.mood.state_of(a).find("freedman") >= 0)
	var legacy := sim.debt.legacy_points
	assert_true(sim.choose_payoff(b.id, false))
	assert_false(b.alive)
	assert_eq(sim.debt.gone[b.id], "left")
	assert_eq(sim.debt.legacy_points, legacy + 1)
	assert_eq(sim.ledger.balance_of("refined_essence"), sim.items.count_world("refined_essence"))


func test_overdue_raises_despair_and_mood() -> void:
	var sim := _sim()
	var c: Colonist = sim.colonists.list[0]
	var st := sim.debt.state_of(c)
	var base := sim.mood.mood_of(c)
	sim.run_ticks(sim.ticks_per_day * (int(sim.defs.debt["due_days"]) + 12) + 40)  # despair 4/day: 12 overdue days > despair_mid
	assert_true(sim.debt.is_overdue(c))
	assert_gt(st.despair, 33.0)
	assert_lt(sim.mood.mood_of(c), base)


func test_riot_trigger_damages_buildings() -> void:
	var sim := _sim(3)
	var c: Colonist = sim.colonists.list[0]
	var other: Colonist = sim.colonists.list[1]
	var riots: Array[int] = []
	sim.bus.riot_started.connect(func(id: int) -> void: riots.append(id))
	sim.debt.cfg["escape_weight"] = 0.0
	var bed := sim.place_instant("bed", sim.map_center() + Vector2i(-3, 4))
	assert_true(bed != null)
	var hp := bed.hp
	var other_mood := sim.mood.mood_of(other)
	_despair(sim, c)
	sim.mood._roll_break(c, sim.mood.state_of(c))
	assert_eq(riots, [c.id])
	assert_eq(c.mood.break_kind, "riot")
	assert_lt(sim.mood.mood_of(other), other_mood)
	sim.run_ticks(int(sim.defs.debt["riot_ticks"]))
	assert_true(bed.destroyed or bed.hp < hp, "building smashed")


func test_escape_trigger_and_item_loss() -> void:
	var sim := _sim(4)
	var c: Colonist = sim.colonists.list[0]
	var escaped: Array[int] = []
	sim.bus.colonist_escaped.connect(func(id: int) -> void: escaped.append(id))
	sim.debt.cfg["escape_weight"] = 1.0
	sim.debt.cfg["escape_patrol_range"] = 0  # nobody on patrol may intercept here
	c.carry_item = "refined_essence"
	c.carry_count = 5
	sim.ledger.record_produced("refined_essence", 5, "test")
	_despair(sim, c)
	sim.mood._roll_break(c, sim.mood.state_of(c))
	assert_eq(c.mood.break_kind, "escape")
	sim.run_ticks(int(sim.defs.debt["escape_ticks"]) + 5)
	assert_eq(escaped, [c.id])
	assert_false(c.alive)
	assert_eq(sim.debt.gone[c.id], "escaped")
	assert_eq(sim.ledger.get_count("escape:refined_essence"), 5)
	assert_eq(sim.ledger.balance_of("refined_essence"), sim.items.count_world("refined_essence"))


func test_escape_stopped_by_drafted_colonist() -> void:
	var sim := _sim(4)
	var c: Colonist = sim.colonists.list[0]
	var guard: Colonist = sim.colonists.list[1]
	sim.debt.cfg["escape_weight"] = 1.0
	guard.cell = c.cell + Vector2i(1, 0)
	sim.set_drafted(guard.id, true)
	_despair(sim, c)
	sim.mood._roll_break(c, sim.mood.state_of(c))
	sim.run_ticks(60)
	assert_true(c.alive, "caught")
	assert_false(sim.debt.gone.has(c.id))
	assert_true(c.job == null or c.job.type != "mental_break")


func test_break_kinds_vary_by_seed() -> void:
	var kinds := {}
	for s in range(1, 13):
		var sim := _sim(s)
		var c: Colonist = sim.colonists.list[0]
		_despair(sim, c)
		sim.mood._roll_break(c, c.mood)
		kinds[c.mood.break_kind] = true
	assert_true(kinds.has("riot") and kinds.has("escape"), str(kinds.keys()))


func test_save_load_and_determinism() -> void:
	var d := peaceful_defs()
	d.debt["due_days"] = 1  # overdue quickly; the test needs no food/stock outside the command log
	var sim := make_sim(9, true, 24, 24, d)
	var c: Colonist = sim.colonists.list[0]
	sim.run_ticks(1)
	sim.set_quota(c.id, 2)
	sim.run_ticks(sim.ticks_per_day * 3)
	assert_gt(sim.debt.state_of(c).despair, 0.0)
	var res := SaveGame.load_json(SaveGame.to_json(sim), make_bus(), d)
	assert_true(res["ok"], str(res["error"]))
	var sim2: Simulation = res["sim"]
	_sims.append(sim2)
	var c2: Colonist = sim2.colonists.list[0]
	assert_eq(sim2.debt.state_of(c2).total, sim.debt.state_of(c).total)
	assert_eq(sim2.debt.state_of(c2).despair, sim.debt.state_of(c).despair)
	assert_eq(sim2.debt.state_of(c2).quota, 2)
	sim.run_ticks(200)
	sim2.run_ticks(200)
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))
	assert_eq(sim2.debt.state_of(c2).despair, sim.debt.state_of(c).despair)


func test_riot_smashing_leaves_no_stale_path() -> void:
	var sim := _sim(3)
	var c: Colonist = sim.colonists.list[0]
	sim.debt.cfg["escape_weight"] = 0.0
	var bed := sim.place_instant("bed", sim.map_center() + Vector2i(-3, 4))
	assert_true(bed != null)
	_despair(sim, c)
	sim.mood._roll_break(c, sim.mood.state_of(c))
	var worst := 0
	for i in int(sim.defs.debt["riot_ticks"]):
		sim.step()
		worst = maxi(worst, c.stuck_ticks)
	assert_lt(worst, 50, "rioter standing at a building keeps a stale path")


func test_patrolling_colonist_catches_escapee() -> void:
	var sim := _sim(3)
	var c: Colonist = sim.colonists.list[0]
	var g: Colonist = sim.colonists.list[1]
	g.cell = c.cell + Vector2i(3, 0)
	assert_false(sim.debt.stopped_by_guard(c))
	g.job = PatrolJob.new([c.cell], 0, 1)
	assert_true(sim.debt.stopped_by_guard(c))
	g.cell = c.cell + Vector2i(9, 0)
	assert_false(sim.debt.stopped_by_guard(c))


func test_shelter_destruction_injures_hidden_colonists() -> void:
	var sim := _sim(4)
	var hq: Building = null
	for b in sim.buildings.list:
		if b.def_id == "hq":
			hq = b
	var c: Colonist = sim.colonists.list[0]
	c.cell = hq.cell
	c.hidden = true
	sim.buildings.destroy(hq)
	assert_false(c.hidden)
	assert_gt(c.health.total_damage() if c.health.total_damage() > 0.0 else 0.0, 0.0)


# region D1
func test_d1_schedule_and_zero_payment_still_breaks() -> void:
	var d: Dictionary = Defs.get_default().debt
	assert_true(int(d["debt_min"]) >= 100, "debt is a heavy sentence (DB)")
	var days_to_break := ceili(float(d["break_despair_min"]) / float(d["despair_per_day"]))
	assert_true(int(d["due_days"]) + days_to_break <= 40, "idle colony reaches break despair by d40")
	var sim := _sim()
	var c: Colonist = sim.colonists.list[0]
	sim.run_ticks(sim.ticks_per_day * (int(d["due_days"]) + days_to_break + 1))
	assert_true(sim.debt.state_of(c).despair >= float(d["break_despair_min"]), "zero payment -> despair")


func test_db_installments_keep_despair_down_and_interest_grows() -> void:
	var sim := _sim()
	var c: Colonist = sim.colonists.list[0]
	var st := sim.debt.state_of(c)
	_stock(sim, 400)
	var inst := int(sim.defs.debt["installment"])
	var total0 := st.total
	for k in 8:  # pay every installment on time for 80 days
		sim.pay_debt(c.id, inst)
		sim.run_ticks(sim.ticks_per_day * int(sim.defs.debt["period_days"]))
	assert_true(st.despair < 1.0, "on schedule -> no despair")
	assert_gt(st.interest, 0)
	assert_gt(st.total, total0)
	assert_gt(st.remaining(), total0 - 8 * inst)
# endregion D1
