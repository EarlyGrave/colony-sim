extends TestCase
## Ammunition: turret buffers, hauling, rifle pouches, policies.


func _scene(seed_value := 5) -> Simulation:
	return make_sim(seed_value, false, 30, 30, peaceful_defs())


func _turret(sim: Simulation, ammo: int) -> Building:
	var b := sim.buildings.place("turret", Vector2i(10, 10), false)
	b.ammo = ammo
	return b


func _crawler(sim: Simulation, cell: Vector2i) -> Enemy:
	var e := sim.threats._spawn("crawler", cell)
	e.hp = 1.0e9
	return e


func test_empty_turret_is_silent() -> void:
	var sim := _scene()
	var b := _turret(sim, 0)
	var fired := [0]
	sim.bus.ammo_depleted.connect(func(_k: String, _i: int) -> void: fired[0] += 1)
	_crawler(sim, Vector2i(13, 10))
	sim.run_ticks(60)
	assert_eq(sim.threats.shots.size(), 0, "no shots without ammo")
	assert_eq(fired[0], 1, "depleted signal once")
	assert_eq(b.ammo, 0)


func test_consumption_per_shot() -> void:
	var sim := _scene()
	var b := _turret(sim, 10)
	_crawler(sim, Vector2i(13, 10))
	sim.run_ticks(40)
	var spent := 10 - b.ammo
	assert_true(spent > 0, "rounds spent")
	assert_eq(sim.ammo.fired, spent)


func test_conserve_policy_holds_fire_at_range() -> void:
	var sim := _scene()
	var b := _turret(sim, 10)
	assert_true(sim.set_turret_ammo_policy(b.id, "conserve"))
	assert_false(sim.set_turret_ammo_policy(b.id, "bogus"))
	assert_false(sim.ammo.turret_try_fire(b, 5.0), "far target ignored")
	assert_eq(b.ammo, 10)
	assert_true(sim.ammo.turret_try_fire(b, 2.0), "close target engaged")
	sim.set_turret_ammo_policy(b.id, "normal")
	assert_true(sim.ammo.turret_try_fire(b, 5.0))
	assert_eq(b.ammo, 8)


func test_haulers_refill_turret() -> void:
	var sim := _scene()
	var b := _turret(sim, 0)
	sim.set_zone(Vector2i(6, 6), "stockpile")
	sim.ledger.record_produced("essence_rounds", 30, "test")
	sim.items.drop(Vector2i(6, 6), "essence_rounds", 30)
	sim.colonists.spawn(Vector2i(7, 7))
	sim.run_ticks(600)
	assert_true(b.ammo >= 20, "turret refilled, has %d" % b.ammo)
	var carried := 0
	for c in sim.colonists.list:
		if c.carry_item == "essence_rounds":
			carried += c.carry_count
	assert_eq(sim.items.count_world("essence_rounds") + carried, sim.ledger.balance_of("essence_rounds"), "ledger conserved")
	assert_eq(sim.ledger.get_count("loaded:essence_rounds"), b.ammo, "moved rounds are in the turret")


func test_rifle_uses_pouch_and_perk_reduces() -> void:
	var counts: Array = []
	for perk in [false, true]:
		var sim := _scene()
		var c := sim.colonists.spawn(Vector2i(5, 5))
		c.combat.weapon = "rifle"
		if perk:
			sim.perks.state_of(c).add_buff("t", {"ammo_use": -0.5}, -1)
		sim.set_drafted(c.id, true)
		_crawler(sim, Vector2i(10, 5))
		sim.run_ticks(300)
		counts.append(sim.ammo.fired)
		assert_eq(c.combat.pouch + sim.ammo.fired, 20)
	assert_true(counts[0] > 0)
	assert_true(counts[1] < counts[0], "perk saves rounds %s" % str(counts))


func test_dry_rifle_does_not_fire() -> void:
	var sim := _scene()
	var c := sim.colonists.spawn(Vector2i(5, 5))
	c.combat.weapon = "rifle"
	sim.set_drafted(c.id, true)
	sim.ammo._pouch_init(c)
	c.combat.pouch = 0
	_crawler(sim, Vector2i(9, 5))
	sim.run_ticks(100)
	assert_eq(sim.ammo.fired, 0)


func test_policy_survives_save_load() -> void:
	var defs := peaceful_defs()
	defs.balance["colony"]["start_items"]["refined_essence"] = 30
	var sim := make_sim(11, true, 24, 24, defs)
	var spot := preload("res://tests/scenario.gd").find_spot(sim, "turret", sim.map_center() + Vector2i(4, 0), 0)
	sim.place_building("turret", spot)
	sim.run_ticks(1500)
	var b := sim.buildings.at(spot)
	assert_true(b != null and b.def_id == "turret", "turret built")
	assert_true(sim.set_turret_ammo_policy(b.id, "conserve"))
	sim.run_ticks(20)
	var res := SaveGame.load_json(SaveGame.to_json(sim), make_bus(), defs)
	assert_true(res["ok"], str(res["error"]))
	var sim2: Simulation = res["sim"]
	_sims.append(sim2)
	assert_eq(sim2.buildings.at(spot).ammo_policy, "conserve")
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))
