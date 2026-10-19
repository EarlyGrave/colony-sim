extends TestCase
## U4: the real-production bot (tools/factory_bot.gd) builds through public commands only, is deterministic,
## and the home map has no nitrogen vents (P3 / fuel cells need an expedition).
const FactoryBot := preload("res://tools/factory_bot.gd")


func test_factory_bot_builds_and_is_deterministic() -> void:
	var a: Dictionary = FactoryBot.play(2, 10, {}, make_bus())
	var b: Dictionary = FactoryBot.play(2, 10, {}, make_bus())
	assert_eq(str(a["built"]), str(b["built"]), "same seed -> same factory")
	assert_eq(str(a["ledger"]), str(b["ledger"]), "same seed -> same ledger")
	assert_true(int(a["steps"]) >= 1, "bot placed its first machine: %s" % str(a["log"]))
	assert_true(int(a["built"].get("miner", 0)) >= 1, "a miner exists")


func test_no_scripted_supply_in_ledger() -> void:
	var sim := Simulation.new(3, make_bus(), null, {"tutorial": true, "research_locked": true})
	sim.start_new_game()
	_sims.append(sim)
	var bot: RefCounted = FactoryBot.new(sim)
	for i in 600:
		bot.act()
		sim.run_ticks(60)
		bot.after()
	for key: String in sim.ledger.by_source:
		assert_false(key.begins_with("bot_supply"), "no scripted supply: " + key)
		assert_false(key.contains("test:"), "no test spawn: " + key)


func test_home_map_has_no_nitrogen_node() -> void:
	for sv in [1, 2, 3, 4, 5]:
		var sim := make_sim(sv)
		var n := 0
		for c in sim.map.node_cells():
			if sim.map.node_resource(c) == "nitrogen":
				n += 1
		assert_eq(n, 0, "seed %d: nitrogen only exists on the vents outpost biome" % sv)
