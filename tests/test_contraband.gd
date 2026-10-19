extends TestCase
## I3 contraband stash + squad shakedown.

const STORE := Vector2i(2, 2)


func _scene(seed_value := 5, enabled := true) -> Simulation:
	var d := peaceful_defs()
	d.contraband["enabled"] = enabled
	var sim := make_sim(seed_value, false, 30, 30, d)
	sim.set_zone(STORE, "stockpile")
	return sim


## Feeds `refined` units (counted as recipe output) and a despairing inmate; runs `days`.
func _run(sim: Simulation, days: int, refined_per_day := 20) -> void:
	var c := sim.colonists.spawn(Vector2i(8, 10))
	sim.form_squad([sim.colonists.spawn(Vector2i(12, 10)).id], ["bulwark"])
	for d in days:
		sim.ledger.record_produced("refined_essence", refined_per_day, "recipe")
		sim.items.drop(STORE, "refined_essence", refined_per_day)
		for st: DebtState in sim.debt.states.values():
			st.despair = 80.0
		for t in sim.ticks_per_day:
			sim.step()
	assert_true(c != null)


func test_skim_capped_at_three_percent_over_seeds() -> void:
	for s in range(1, 11):
		var sim := _scene(s)
		_run(sim, 6)
		var out := sim.ledger.get_count("recipe:refined_essence")
		assert_true(sim.contraband.skimmed > 0, "seed %d skims" % s)
		assert_true(sim.contraband.skimmed <= int(out * 0.03), "seed %d skim <= 3%%" % s)


func test_conservation_and_shakedown() -> void:
	var ok := 0
	for s in range(1, 11):
		var sim := _scene(s)
		_run(sim, 4)
		var cb := sim.contraband
		var before := cb.recovered
		if sim.squad_shakedown(1) or cb.stash_total() == 0:
			ok += 1
		assert_eq(cb.skimmed, cb.stash_total() + cb.recovered + cb.leaked, "seed %d conserved" % s)
		assert_eq(sim.ledger.get_count("skim:refined_essence"), cb.skimmed)
		assert_true(cb.recovered >= before)
		assert_false(sim.squad_shakedown(1), "cooldown or empty stash rejects a second one")
	assert_true(ok >= 8, "shakedown possible in >= 8/10 seeds")


func test_shakedown_spikes_despair() -> void:
	var sim := _scene()
	_run(sim, 3)
	var cb := sim.contraband
	assert_gt(cb.stash_total(), 0)
	var top := cb._top_holder()
	(sim.debt.states[top] as DebtState).despair = 10.0
	assert_true(sim.squad_shakedown(1))
	assert_eq((sim.debt.states[top] as DebtState).despair, 35.0)
	assert_eq(cb.stash_total(), 0)


func test_black_market_bumps_waves() -> void:
	var d := peaceful_defs()
	d.contraband["enabled"] = true
	d.contraband["blackmarket_stash"] = 2
	var sim := make_sim(5, false, 30, 30, d)
	sim.set_zone(STORE, "stockpile")
	assert_eq(sim.contraband.wave_mult(), 1.0)
	_run(sim, 5)
	assert_gt(sim.contraband.blackmarkets, 0)
	assert_gt(sim.contraband.leaked, 0)
	var cb := sim.contraband
	assert_eq(cb.skimmed, cb.stash_total() + cb.recovered + cb.leaked)


func test_disabled_is_inert_and_deterministic() -> void:
	var a := _scene(5, false)
	_run(a, 4)
	assert_eq(a.contraband.skimmed, 0)
	assert_eq(a.contraband.wave_mult(), 1.0)
	assert_false(a.squad_shakedown(1))
	var h1 := SaveGame.state_hash(_hash_run(5))
	var h2 := SaveGame.state_hash(_hash_run(5))
	assert_eq(h1, h2, "same seed -> same hash")


func _hash_run(seed_value: int) -> Simulation:
	var sim := _scene(seed_value)
	_run(sim, 4)
	sim.squad_shakedown(1)
	return sim


# region N2: covert trade
func _covert(seed_value := 5) -> Simulation:
	var d := peaceful_defs()
	d.contraband["enabled"] = false
	d.balance["q_enabled"] = true
	var sim := make_sim(seed_value, false, 30, 30, d)
	sim.set_zone(STORE, "stockpile")
	sim.ledger.record_produced("refined_essence", 100, "recipe")
	sim.items.drop(STORE, "refined_essence", 100)
	return sim


func test_flag_activates_and_sale_needs_escape_path() -> void:
	var sim := _covert()
	assert_false(sim.contraband.is_enabled())
	assert_false(sim.covert_sale(5), "off without the flag")
	sim.quests.set_flag("contraband_on")
	assert_true(sim.contraband.is_enabled())
	assert_eq(sim.contraband.can_covert_sale(5), "no_escape_path")
	assert_false(sim.covert_sale(5))
	assert_eq(sim.contraband.escape_credit, 0)


func test_sale_credit_and_suspicion_rules() -> void:
	var sim := _covert()
	sim.quests.set_flag("contraband_on")
	sim.quests.set_flag("path_escape")
	var before := sim.items.count_stored("refined_essence")
	assert_true(sim.covert_sale(5))
	assert_eq(sim.contraband.escape_credit, 5)
	assert_eq(sim.items.count_stored("refined_essence"), before - 5)
	var base := sim.contraband.suspicion
	assert_eq(base, 10.0 * (2.0 if SocietyConds.informant_alive(sim) else 1.0) / 1.0 * 1.0, "2 per unit, doubled with Informant")
	assert_false(sim.covert_sale(500), "not enough stock")
	var sim2 := _covert()
	sim2.quests.set_flag("contraband_on")
	sim2.quests.set_flag("path_escape")
	sim2.colonists.spawn(Vector2i(8, 10))
	sim2.contraband.suspicion = 20.0
	sim2.contraband.stash[1] = 1
	sim2.contraband.skimmed = 1
	sim2.form_squad([sim2.colonists.spawn(Vector2i(12, 10)).id], ["bulwark"])
	assert_true(sim2.squad_shakedown(1))
	assert_eq(sim2.contraband.suspicion, 10.0, "shakedown lowers suspicion by 10")


func test_inspection_at_60_and_decay() -> void:
	var sim := _covert()
	sim.quests.set_flag("contraband_on")
	sim.quests.set_flag("path_escape")
	sim.contraband.suspicion = 59.0
	assert_true(sim.covert_sale(1))  # +2 (or +4 with Informant): 59 -> inspection band, not raid
	assert_eq(sim.contraband.inspections, 1)
	assert_eq(sim.quests.mod("audit_parts_mult"), 1.3)
	var s0 := sim.contraband.suspicion
	for t in sim.ticks_per_day * 2:
		sim.step()
	assert_lt(sim.contraband.suspicion, s0, "decays daily")


func test_missed_installment_triggers_skim_and_conserves() -> void:
	var sim := _covert()
	sim.quests.set_flag("contraband_on")
	sim.colonists.spawn(Vector2i(8, 10))
	var dc: Dictionary = sim.defs.debt
	dc["installment"] = 100000  # unreachable, so the colonist's own payments cannot cover it
	sim.step()  # debt states are created lazily on the first tick
	for st: DebtState in sim.debt.states.values():
		st.due_day = -20  # installment long overdue; the colony only survives ~4 days, so do not wait for the real deadline
	for d in 3:
		for t in sim.ticks_per_day - 1:
			sim.step()
		for st: DebtState in sim.debt.states.values():
			st.despair = 0.0
			st.period_paid = 0  # unpaid right before the daily skim check (the colonist pays from the store mid-day)
		sim.step()
	var cb := sim.contraband
	assert_gt(cb.skimmed, 0, "missed installment skims without despair")
	assert_true(cb.skimmed <= int(sim.ledger.get_count("recipe:refined_essence") * 0.03))
	assert_eq(cb.skimmed, cb.stash_total() + cb.recovered + cb.leaked)


func test_covert_deterministic() -> void:
	var hs: Array = []
	for i in 2:
		var sim := _covert(7)
		sim.quests.set_flag("contraband_on")
		sim.quests.set_flag("path_escape")
		sim.covert_sale(10)
		for t in sim.ticks_per_day * 3:
			sim.step()
		hs.append(SaveGame.state_hash(sim))
	assert_eq(hs[0], hs[1])
# endregion
