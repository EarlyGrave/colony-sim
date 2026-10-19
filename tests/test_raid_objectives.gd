extends TestCase
## Raid objectives (W1): gorge eats stock and ends the wave, wreck ends on the target breaking, hunt unchanged.


func _defs(on := true) -> Defs:
	var d := Defs.get_default().duplicate_defs()
	d.balance["threat"]["base_strength"] = 6.0
	d.balance["threat"]["first_wave_max_points"] = 1000.0
	d.balance["threat"]["raid_objectives"] = on
	for id: String in ["swarm", "spitters", "brute_pack"]:
		d.raids[id]["objective"] = "gorge" if id == "swarm" else "wreck"
	return d


func _base(defs: Defs) -> Simulation:
	var sim := make_sim(21, false, 40, 40, defs)
	sim.buildings.place("hq", Vector2i(19, 19), false)
	return sim


func test_gorge_ends_wave_without_inmate_damage() -> void:
	var sim := _base(_defs())
	var c := sim.colonists.spawn(Vector2i(30, 30))
	c.hidden = true
	sim.items.add_at(Vector2i(10, 20), "waste", 20)
	var met: Array = []
	sim.bus.raid_objective_met.connect(func(id: String, k: String) -> void: met.append(k))
	sim.threats.force_raid_id = "swarm"
	sim.threats.start_wave()
	assert_eq(sim.threats.get_objective().kind, "gorge")
	sim.run_ticks(3000)
	assert_eq(met, ["gorge"], "objective met once")
	assert_false(sim.threats.wave_active, "wave ended")
	assert_true(sim.items.count_on_ground("waste") < 20, "stock eaten")
	assert_gt(int(sim.ledger.by_source.get("raid_lost:waste", 0)), 0)
	var kinds := {}
	for inj in c.health.injuries:
		kinds[inj.kind] = true
	assert_false(kinds.has("bite"), "no inmate damage from creatures: %s" % str(kinds.keys()))


func test_gorge_falls_back_to_hunt_without_stock() -> void:
	var sim := _base(_defs())
	sim.threats.force_raid_id = "swarm"
	sim.threats.start_wave()
	assert_eq(sim.threats.get_objective().kind, "hunt")


func test_wreck_ends_on_target_broken() -> void:
	var sim := _base(_defs())
	sim.threats.force_raid_id = "brute_pack"
	sim.threats.start_wave()
	var o: RaidObjective = sim.threats.get_objective()
	assert_eq(o.kind, "wreck")
	var ref := sim.buildings.place("refinery", Vector2i(24, 19), false)
	o.target_id = ref.id
	var met: Array = []
	sim.bus.raid_objective_met.connect(func(id: String, k: String) -> void: met.append(k))
	sim.buildings.damage(sim.buildings.get_by_id(o.target_id), 1000000.0)
	sim.run_ticks(2)
	assert_eq(met, ["wreck"])
	assert_true(sim.threats.retreating)


func test_flag_off_is_hunt() -> void:
	var sim := _base(_defs(false))
	sim.items.add_at(Vector2i(10, 20), "waste", 20)
	sim.threats.force_raid_id = "swarm"
	sim.threats.start_wave()
	assert_true(sim.threats.get_objective() == null)
