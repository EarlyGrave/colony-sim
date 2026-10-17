extends TestCase
## E6: creature waves. Fixed seeds, full simulation.

const Scenario := preload("res://tests/scenario.gd")
const SEED := 1


func _colony(seed_value: int, turrets: int) -> Simulation:
	var sim := make_sim(seed_value)
	Scenario.standard_colony(sim, turrets)
	return sim


func test_without_turrets_colony_dies_on_wave_2_or_3() -> void:
	for s in [SEED, 2, 3]:
		var r := Scenario.run_waves(_colony(s, 0), 8)
		assert_ne(r["game_over"], "", "seed %d: colony should fall" % s)
		assert_true(r["died_on_wave"] in [2, 3], "seed %d: died on wave %d" % [s, r["died_on_wave"]])


func test_turrets_hold_but_static_defense_is_not_enough() -> void:
	var r := Scenario.run_waves(_colony(SEED, 3), 10)
	assert_gt(r["log"].size(), 3, "turrets should hold at least 3 waves")
	assert_eq(r["log"][0]["kills"], r["log"][0]["enemies"], "first wave should be wiped out by turrets")
	# Waves grow with the colony: without the player's help it falls anyway.
	assert_ne(r["game_over"], "", "untouched defense should eventually fail")


func test_player_intervention_keeps_colony_alive_longer() -> void:
	var static_r := Scenario.run_waves(_colony(SEED, 3), 10)
	var sim := _colony(SEED, 3)
	var r := Scenario.run_waves(sim, 10, true)
	var survived := func(res: Dictionary) -> int:
		return res["waves"] if res["game_over"] == "" else res["died_on_wave"] - 1
	assert_true(survived.call(r) >= survived.call(static_r) + 2,
		"rebuilding turrets should buy at least 2 waves (static %d, active %d)" % [survived.call(static_r), survived.call(r)])
	assert_gt(r["turrets_built"], 3)
	for item in sim.defs.items:
		assert_eq(sim.items.count_world(item), sim.ledger.balance_of(item), "%s leaked" % item)


func test_wave_strength_grows_with_refining_and_contamination() -> void:
	var sim := make_sim(5, false, 20, 20)
	var base := sim.threats.wave_strength(1)
	assert_gt(sim.threats.wave_strength(3), base, "later waves are stronger")
	sim.ledger.record_produced("refined_essence", 100, "recipe")
	var refined := sim.threats.wave_strength(1)
	assert_gt(refined, base, "refined essence attracts creatures")
	sim.contamination.level = 30.0
	assert_gt(sim.threats.wave_strength(1), refined, "contamination attracts creatures")


func test_mining_alone_wakes_creatures() -> void:
	var sim := make_sim(6, false, 20, 20)
	sim.colonists.spawn(Vector2i(2, 2))
	sim.map.set_tile(Vector2i(10, 10), MapGrid.Tile.DEPOSIT, 500)
	sim.designate_mine(Vector2i(10, 10), true)
	assert_false(sim.threats.awakened)
	sim.run_ticks(1500)
	assert_true(sim.threats.awakened, "mining %d ore should wake the threat" % sim.ledger.get_count("mining:essence_ore"))


func test_colonists_hide_during_wave_and_come_out_after() -> void:
	var sim := make_sim(SEED)
	Scenario.standard_colony(sim, 4)
	sim.threats.awaken()
	sim.threats.next_wave_tick = sim.tick + 1
	sim.run_ticks(2)
	assert_true(sim.threats.wave_active)
	assert_true(sim.alarm)
	sim.run_ticks(80)
	for c in sim.colonists.list:
		assert_true(c.hidden, "%s should hide in the capsule" % c.display_name)
	var guard := 0
	while sim.threats.wave_active and guard < 2000:
		sim.step()
		guard += 1
	assert_false(sim.alarm, "alarm lifted after the wave")
	sim.run_ticks(5)
	for c in sim.colonists.list:
		assert_false(c.hidden, "%s should come out" % c.display_name)


func test_enemies_go_for_key_buildings() -> void:
	var sim := make_sim(7, false, 30, 30)
	sim.buildings.place("hq", Vector2i(14, 14), false)
	var ref := sim.buildings.place("refinery", Vector2i(20, 14), false)
	var e := sim.threats._spawn("crawler", Vector2i(0, 15))
	sim.threats._choose_target(e)
	assert_eq(e.target_kind, Enemy.Target.BUILDING)
	assert_eq(e.target_id, ref.id, "refinery has the highest threat priority")


func test_turret_kills_enemy_in_range() -> void:
	var sim := make_sim(8, false, 20, 20)
	sim.buildings.place("turret", Vector2i(10, 10), false)
	var e := sim.threats._spawn("crawler", Vector2i(14, 10))
	e.move_ticks = 1000000  # stand still
	sim.run_ticks(100)
	assert_false(sim.threats.enemies.has(e), "turret should kill a crawler in range")
	assert_eq(sim.threats.kills, 1)


func test_enemy_catches_walking_colonist() -> void:
	var sim := make_sim(9, false, 30, 10, peaceful_defs())
	var c := sim.colonists.spawn(Vector2i(4, 5))
	sim.health.apply_damage(c, 96.0, "torso", "bruise")  # nearly dead: one more bite kills
	c.carry_item = "essence_ore"
	c.carry_count = 5
	sim.ledger.record_produced("essence_ore", 5, "test")
	var e := sim.threats._spawn("crawler", Vector2i(2, 5))
	var start := e.cell
	var died := [false]
	sim.bus.colonist_died.connect(func(_id: int) -> void: died[0] = true)
	for i in 600:
		# The colonist keeps walking away, re-pathing every few ticks.
		c.move_toward(Vector2i(28 if (i / 40) % 2 == 0 else 1, 5), sim)
		sim.threats._tick_enemy(e)
		if died[0]:
			break
	assert_ne(e.cell, start, "crawler must move while chasing")
	assert_true(died[0], "crawler must be able to catch a walking colonist")
	assert_eq(sim.items.count_world("essence_ore"), 5, "carried ore dropped on death")


func test_shelter_keeps_colonists_hidden_when_other_buildings_fall() -> void:
	var sim := make_sim(10, false, 20, 20, peaceful_defs())
	var hq := sim.buildings.place("hq", Vector2i(8, 8), false)
	var t := sim.buildings.place("turret", Vector2i(14, 8), false)
	var c := sim.colonists.spawn(Vector2i(2, 2))
	sim.set_alarm(true)
	sim.run_ticks(60)
	assert_true(c.hidden)
	sim.buildings.destroy(t)
	assert_true(c.hidden, "losing a turret must not open the shelter")
	sim.buildings.destroy(hq)
	assert_false(c.hidden, "destroyed shelter releases its occupants")


func test_waves_conserve_items_and_stay_deterministic() -> void:
	var a := _colony(3, 3)
	var b := _colony(3, 3)
	Scenario.run_waves(a, 5, true)
	Scenario.run_waves(b, 5, true)
	assert_eq(a.tick, b.tick)
	assert_eq(a.items.stacks, b.items.stacks)
	assert_eq(a.threats.kills, b.threats.kills)
	for item in a.defs.items:
		assert_eq(a.items.count_world(item), a.ledger.balance_of(item), "%s leaked" % item)
	assert_true(a.jobs.reserved.size() <= a.colonists.alive_count(), "stale reservations: %s" % str(a.jobs.reserved))
