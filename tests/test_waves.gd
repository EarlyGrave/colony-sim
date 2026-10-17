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


func test_player_intervention_keeps_colony_alive() -> void:
	var sim := _colony(SEED, 3)
	var r := Scenario.run_waves(sim, 8, true)
	assert_eq(r["game_over"], "", "rebuilding turrets should save seed %d" % SEED)
	assert_eq(r["waves"], 8)
	assert_gt(r["turrets_built"], 3)
	assert_eq(sim.items.count_world("refined_essence"), sim.ledger.balance_of("refined_essence"))


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
