extends TestCase
## R4b: expedition sim hooks (opts crew/supplies/no_refining, dispatch_party, receive_cargo).


func _mk(seed_value: int, opts := {}) -> Simulation:
	var o := {"map_w": 64, "map_h": 64}
	o.merge(opts, true)
	var sim := Simulation.new(seed_value, make_bus(), peaceful_defs(), o)
	sim.start_new_game()
	_sims.append(sim)
	return sim


func test_default_start_deterministic() -> void:
	var a := _mk(5)
	var b := _mk(5)
	a.run_ticks(200)
	b.run_ticks(200)
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b))
	assert_eq(a.colonists.alive_count(), 4)


func test_dispatch_removes_exactly_n_and_supplies() -> void:
	var sim := _mk(11)
	var ids: Array = [sim.colonists.list[0].id, sim.colonists.list[1].id]
	var ore := sim.items.count_stored("essence_ore")
	var r := sim.dispatch_party(ids, {"essence_ore": 7})
	assert_true(r["ok"])
	assert_eq(r["crew"].size(), 2)
	assert_eq(sim.colonists.alive_count(), 2)
	assert_eq(sim.items.count_stored("essence_ore"), ore - 7)


func test_dispatch_rejects_without_change() -> void:
	var sim := _mk(11)
	var before := SaveGame.state_hash(sim)
	var id0: int = sim.colonists.list[0].id
	assert_false(sim.dispatch_party([9999], {})["ok"])
	assert_false(sim.dispatch_party([id0], {"essence_ore": 99999})["ok"])
	assert_false(sim.dispatch_party([id0, id0], {})["ok"])
	assert_eq(SaveGame.state_hash(sim), before)
	assert_eq(sim.colonists.alive_count(), 4)


func test_receive_cargo_lands_or_records_lost() -> void:
	var sim := _mk(11)
	var lost := sim.receive_cargo({"raw_food": 20}, 4)
	assert_eq(sim.ledger.balance_of("raw_food"), sim.items.count_world("raw_food"))
	assert_eq(lost, 0)


func test_replay_equal_hash() -> void:
	var a := _mk(3)
	a.run_ticks(30)
	a.dispatch_party([a.colonists.list[0].id], {"raw_food": 3})
	a.run_ticks(30)
	a.receive_cargo({"raw_food": 12}, 5)
	a.run_ticks(60)
	var parsed: Variant = JSON.parse_string(JSON.stringify(SaveGame.to_dict(a)))
	var b := SaveGame._replay(parsed, make_bus(), a.defs, Callable())
	_sims.append(b)
	assert_eq(SaveGame.state_hash(b), SaveGame.state_hash(a))


func test_crew_start_and_no_refining() -> void:
	var crew := [{"name": "Zed", "engineer": false, "skills": {"mining": 9}}, {"name": "Amy", "engineer": true, "skills": {}}]
	var sim := _mk(21, {"crew": crew, "supplies": {"raw_food": 5}, "no_refining": true})
	assert_eq(sim.colonists.list.size(), 2)
	assert_eq(sim.colonists.list[0].display_name, "Zed")
	assert_eq(sim.colonists.list[0].skills.levels["mining"], 9)
	assert_eq(sim.items.count_world("raw_food"), 5)
	assert_eq(sim.items.count_world("essence_ore"), 0)
	assert_true(sim.is_refining_building("refinery"))
	assert_true(sim.can_place_building("refinery", sim.map_center() + Vector2i(8, 8)) != "")
	assert_false(sim.is_refining_building("turret"))
