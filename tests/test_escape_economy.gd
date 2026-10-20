extends TestCase
## F4a: Escape path numbers: the sale loop reaches the bandit fee without a sure raid, and the pickup pays into legacy.


func _sim() -> Simulation:
	var d := peaceful_defs()
	d.balance["e1_enabled"] = true
	d.balance["q_enabled"] = true
	d.endings["escape"]["pursuit_mult"] = 0.0
	var sim := make_sim(5, false, 30, 30, d)
	sim.colonists.spawn(Vector2i(4, 4))
	sim.set_zone(Vector2i(10, 10), "stockpile")
	sim.run_ticks(1)
	sim.set_path("escape")
	sim.quests.set_flag("contraband_on")
	sim.ledger.record_produced("refined_essence", 400, "recipe")
	sim.items.drop(Vector2i(10, 10), "refined_essence", 400)
	sim.defs.contraband["inspection_confiscate"] = 0
	return sim


func test_extraction_pays_legacy() -> void:
	var sim := _sim()
	var base := Legacy.summarize(sim, "test")
	assert_eq(base["extracted"], 0)
	sim.contraband.sales = 3
	sim.contraband.escape_credit = 60
	assert_true(sim.contact_bandits())
	assert_true(sim.pay_bandit_fee())
	assert_true(sim.start_extraction())
	sim.run_ticks(sim.ticks_per_day - 2)
	var c: Colonist = sim.colonists.list[0]
	c.cell = sim.fight_escape.extract_cell
	c.clear_path()
	c.job = null
	c.idle_until = sim.tick + 100
	sim.run_ticks(4)
	assert_true(sim.endings.won("escape"))
	var s := Legacy.summarize(sim, "escape")
	assert_eq(s["extracted"], 1)
	var per: float = float(sim.defs.contraband["legacy"]["per_extracted"])
	assert_gt(s["escape_points"], 0.0)
	assert_true(s["escape_points"] >= per)
	assert_gt(s["legacy"], base["legacy"], "extraction adds legacy")


func test_unspent_credit_counts_but_is_capped() -> void:
	var sim := _sim()
	sim.contraband.escape_credit = 10
	var lw: Dictionary = sim.defs.contraband["legacy"]
	assert_eq(Legacy.escape_points(sim), 10.0 * float(lw["per_credit"]))
	sim.contraband.escape_credit = 10000
	assert_eq(Legacy.escape_points(sim), float(lw["credit_cap"]) * float(lw["per_credit"]))


func test_selling_cadence_pays_fee_and_never_tops_100() -> void:
	# the bot's rhythm: 10 refined every 6 days, with the Informant doubling suspicion (worst case)
	var sim := _sim()
	var peak := 0.0
	var fee: int = sim.fight_escape.bandit_fee()
	for day in range(1, 61):
		sim.run_ticks(sim.ticks_per_day)
		if day % 6 == 0 and sim.contraband.escape_credit < fee:
			sim.covert_sale(10)
		peak = maxf(peak, sim.contraband.suspicion)
	assert_lt(peak, 100.0, "suspicion cap holds")
	assert_lt(float(sim.defs.contraband["suspicion_cap"]), 100.0)
	assert_gt(sim.contraband.sales, 3, "enough sales to contact the bandits")
