extends TestCase
## Metropolis track skeleton (MT): defiance clock, drone raids, no stacking, determinism, disabled = inert.


func _defs(on := true) -> Defs:
	var d := Defs.get_default().duplicate_defs()
	d.balance["metro"]["enabled"] = on
	d.balance["metro"]["first_raid_day"] = 0.0
	d.balance["threat"]["first_wave_max_points"] = 1000.0
	return d


func _sim(on := true, seed_value := 31) -> Simulation:
	var sim := make_sim(seed_value, false, 40, 40, _defs(on))
	sim.buildings.place("hq", Vector2i(19, 19), false)
	sim.threats.awakened = true
	sim.threats.next_wave_tick = sim.tick + sim.ticks_per_day * 50
	return sim


func test_clock_math() -> void:
	var m := _sim().threats.metro()
	m.add_defiance(10.0)
	m.note_declined_audit()
	assert_eq(m.defiance, 20.0)
	m.note_covert_sale(4)
	assert_eq(m.defiance, 22.0)
	m.add_defiance(-500.0)
	assert_eq(m.defiance, 0.0)
	m.add_defiance(500.0)
	assert_eq(m.defiance, 100.0)


func test_unmet_quota_day_raises_and_shipping_decays() -> void:
	var sim := _sim()
	var c := sim.colonists.spawn(Vector2i(10, 10))
	sim.debt._assign(c)
	var st := sim.debt.state_of(c)
	st.quota = 5
	var m := sim.threats.metro()
	m.daily()  # baseline day: nothing paid yet, quota unmet
	assert_eq(m.defiance, 2.0)
	st.paid += 5
	m.daily()
	assert_eq(m.defiance, 0.0, "a shipping day decays defiance (clamped at 0)")
	m.add_defiance(20.0)
	st.paid += 1
	m.daily()
	assert_eq(m.defiance, 17.0)


func test_points_and_fight_escalation() -> void:
	var m := _sim().threats.metro()
	m.add_defiance(20.0)
	assert_eq(m.points(), 2.0 + 0.15 * 20.0)
	assert_false(m.fight_path())
	m.add_defiance(50.0)
	assert_true(m.fight_path())
	var p0 := m.points()
	m.raids_started = 2
	assert_true(m.points() > p0, "fight path escalates per raid")
	m.raids_started = 4
	assert_eq(m.pick_raid(), "collector_assault")


func test_drone_raid_starts_with_energy_enemies() -> void:
	var sim := _sim()
	var m := sim.threats.metro()
	m.add_defiance(40.0)
	var seen: Array = []
	sim.bus.metro_raid_started.connect(func(id: String, _p: float) -> void: seen.append(id))
	assert_true(m.tick())
	assert_eq(seen.size(), 1)
	assert_true(sim.threats.wave_active)
	assert_eq(str(sim.defs.raids[sim.threats.raid_id]["faction"]), "metropolis")
	for _i in sim.ticks_per_day:
		sim.step()
	var drones := 0
	for e in sim.threats.enemies:
		assert_eq(str(e.def.get("dmg_type")), "energy")
		assert_true(float(e.def_stats[StatBlock.ARM_ENERGY]) > 0.0)
		drones += 1
	assert_true(drones > 0 or sim.threats.raid_total > 0)


func test_never_stacks_with_creature_wave() -> void:
	var sim := _sim()
	var m := sim.threats.metro()
	m.add_defiance(40.0)
	sim.threats.next_wave_tick = sim.tick + 10  # creature wave imminent
	assert_false(m.tick(), "imminent creature wave blocks the drones")
	sim.threats.next_wave_tick = sim.tick + sim.ticks_per_day * 50
	sim.threats.force_raid_id = "swarm"
	sim.threats.start_wave()
	assert_false(m.tick(), "active wave blocks the drones")
	sim.threats.end_wave()
	assert_true(m.next_raid_tick >= sim.tick + int(sim.ticks_per_day), "creature wave end delays drones by grace_days")
	sim = _sim()
	m = sim.threats.metro()
	m.add_defiance(40.0)
	assert_true(m.tick())
	assert_true(sim.threats.next_wave_tick >= sim.threats.wave_end_tick + sim.ticks_per_day, "drone raid defers the creature timer")


func test_creature_picker_ignores_metro_raids() -> void:
	var sim := _sim()
	for i in 40:
		var id := sim.threats.pick_raid_type(50.0)
		assert_true(id == "" or str(sim.defs.raids[id].get("faction", "creature")) == "creature")


func _run(seed_value: int) -> Array:
	var sim := _sim(true, seed_value)
	sim.threats.metro().add_defiance(60.0)
	for _i in sim.ticks_per_day * 3:
		sim.step()
	var m := sim.threats.metro()
	return [m.defiance, m.raids_started, sim.threats.wave_index, sim.threats.enemies.size(), sim.threats.raid_total]


func test_deterministic() -> void:
	assert_eq(_run(5), _run(5))


func test_disabled_is_inert() -> void:
	var sim := _sim(false)
	var m := sim.threats.metro()
	assert_false(m.enabled())
	m.note_declined_audit()
	m.note_covert_sale(10)
	assert_eq(m.defiance, 0.0)
	assert_false(m.tick())
	assert_false(sim.defs.raids.has("drone_sweep"))
	for _i in sim.ticks_per_day * 2:
		sim.step()
	assert_eq(m.raids_started, 0)
	assert_eq(sim.threats.wave_index, 0)
