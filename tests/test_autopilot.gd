extends TestCase
## Autopilot: exact analytic yield, buffer cap, raid roll isolation.


func _defs(hazard := 0) -> Defs:
	var d := peaceful_defs()
	d.resources["pure_ore"] = {"item": "pure_ore", "tier": 2, "base_rate": 10.0,
		"purity_mult": {"impure": 0.5, "normal": 1.0, "pure": 2.0}}
	d.biomes["test_biome"] = {"hazard": hazard, "yield_mult": 1.0}
	return d


func _ledger(cfg: Dictionary, miners: int) -> Dictionary:
	var led := Autopilot.new_ledger("test_biome", 99, cfg, "pure_ore")
	led["miners"] = miners
	led["purity"] = "pure"
	led["supplies"] = {"raw_food": 100000}
	return led


func test_ten_days_exact_formula() -> void:
	var d := _defs()
	var cfg := Campaign.load_cfg()
	cfg["buffer_cap"] = 100000
	var led := _ledger(cfg, 5)
	var tpd := int(d.balance["ticks_per_day"])
	# 5 miners * base 10 * pure 2.0 * yield_mult 1.0 * tpd / rate_ticks
	var per_day := floori(5.0 * 10.0 * 2.0 * float(tpd) / float(cfg["rate_ticks"]))
	for i in 10:
		Autopilot.advance_day(led, d, cfg, tpd)
	assert_eq(int(led["buffer"]["pure_ore"]), per_day * 10)
	assert_eq(int(led["supplies"]["raw_food"]), 100000 - 5 * 10)


func test_buffer_never_exceeds_cap() -> void:
	var d := _defs()
	var cfg := Campaign.load_cfg()
	cfg["buffer_cap"] = 250
	var led := _ledger(cfg, 5)
	var tpd := int(d.balance["ticks_per_day"])
	for i in 30:
		Autopilot.advance_day(led, d, cfg, tpd)
		assert_true(Autopilot.buffer_total(led) <= 250)
	assert_eq(Autopilot.buffer_total(led), 250)


func test_unfed_outpost_produces_nothing() -> void:
	var d := _defs()
	var cfg := Campaign.load_cfg()
	var led := _ledger(cfg, 5)
	led["supplies"] = {"raw_food": 4}
	Autopilot.advance_day(led, d, cfg, int(d.balance["ticks_per_day"]))
	assert_eq(Autopilot.buffer_total(led), 0)


func test_raid_roll_is_deterministic_and_kills_outpost() -> void:
	var d := _defs(6)
	var cfg := Campaign.load_cfg()
	var a := _ledger(cfg, 2)
	var b := _ledger(cfg, 2)
	var tpd := int(d.balance["ticks_per_day"])
	for i in 60:
		Autopilot.advance_day(a, d, cfg, tpd)
		Autopilot.advance_day(b, d, cfg, tpd)
	assert_eq(var_to_str(a), var_to_str(b))
	assert_true(bool(a["lost"]))
	assert_eq(int(a["integrity"]), 0)


func test_autopilot_does_not_touch_sim_rng() -> void:
	var sim := make_sim(5, true, 24, 24, _defs(6))
	var probe := RandomNumberGenerator.new()
	probe.seed = sim.rng.seed
	probe.state = sim.rng.state
	var before := sim.rng.state
	var cfg := Campaign.load_cfg()
	var led := _ledger(cfg, 3)
	for i in 20:
		Autopilot.advance_day(led, sim.defs, cfg, sim.ticks_per_day)
	assert_eq(sim.rng.state, before)
