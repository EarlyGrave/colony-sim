extends TestCase
## Storyteller arrivals: wanderer, pod crash, transport drop, fallout, cargo.


func _sim(seed_value := 5) -> Simulation:
	var sim := make_sim(seed_value, true, 24, 24, peaceful_defs())
	return sim


func _fire_and_pending(sim: Simulation, id: String) -> Dictionary:
	assert_true(sim.storyteller.fire(id), "fire " + id)
	return sim.storyteller.pending[0]


func test_wanderer_accept_adds_working_colonist() -> void:
	var sim := _sim()
	var scen := preload("res://tests/scenario.gd")
	scen.standard_colony(sim, 0)
	var before := sim.colonists.alive_count()
	var p := _fire_and_pending(sim, "wanderer")
	assert_eq(sim.colonists.alive_count(), before, "not joined before the answer")
	var c: Colonist = p["colonist"]
	assert_true(sim.answer_event(int(p["uid"]), true))
	assert_eq(sim.colonists.alive_count(), before + 1)
	assert_true(sim.storyteller.pending.is_empty())
	sim.run_ticks(400)
	assert_true(c.stuck_ticks < 100, "moves")
	assert_true(c.job != null or c.cell != sim.map_center() or sim.jobs != null)
	assert_true(c.skills.priority("mining") > 0, "has work priorities")
	assert_true(c.bio.has("backstory"))


func test_wanderer_decline_and_timeout() -> void:
	var sim := _sim()
	var before := sim.colonists.alive_count()
	var p := _fire_and_pending(sim, "wanderer")
	assert_true(sim.answer_event(int(p["uid"]), false))
	assert_eq(sim.colonists.alive_count(), before)
	assert_false(sim.answer_event(int(p["uid"]), true), "already answered")
	_fire_and_pending(sim, "wanderer")
	sim.run_ticks(int(sim.defs.arrivals["choice_timeout_ticks"]) + 5)
	assert_true(sim.storyteller.pending.is_empty(), "auto-declined")
	assert_eq(sim.colonists.alive_count(), before)


func test_pod_survivor_joins_after_tend() -> void:
	var sim := _sim()
	var before := sim.colonists.alive_count()
	var p := _fire_and_pending(sim, "pod_crash")
	var c: Colonist = p["colonist"]
	assert_true(c.health != null and not c.health.injuries.is_empty(), "wounded")
	sim.run_ticks(200)
	assert_eq(sim.colonists.alive_count(), before, "not joined while untended")
	assert_true(sim.answer_event(int(p["uid"]), true))
	assert_eq(sim.colonists.alive_count(), before, "rescue alone does not join")
	sim.run_ticks(200)
	assert_eq(sim.colonists.alive_count(), before + 1, "joined after tend")
	assert_true(sim.storyteller._find_pending(int(p["uid"])).is_empty(), "survivor no longer pending")


func test_pod_survivor_manual_tend() -> void:
	var sim := _sim()
	var before := sim.colonists.alive_count()
	var p := _fire_and_pending(sim, "pod_crash")
	sim.answer_event(int(p["uid"]), true)
	sim.health.tend(p["colonist"])
	sim.run_ticks(2)
	assert_eq(sim.colonists.alive_count(), before + 1)


func test_transport_drop_joins_automatically() -> void:
	var sim := _sim()
	var before := sim.colonists.alive_count()
	assert_true(sim.storyteller.fire("transport_drop"))
	assert_true(sim.colonists.alive_count() > before)


func test_colonist_cap() -> void:
	var sim := _sim()
	var cap := int(sim.defs.arrivals["max_colonists"])
	var guard := 20
	while sim.colonists.alive_count() < cap and guard > 0:
		guard -= 1
		sim.storyteller.fire("transport_drop")
	assert_true(sim.colonists.alive_count() <= cap)
	sim.colonists.add(ColonistGenerator.generate(sim, sim.map_center()))
	assert_false(sim.storyteller.fire("wanderer"), "no room for more")


func test_lightning_capped() -> void:
	var sim := _sim()
	var scen := preload("res://tests/scenario.gd")
	scen.standard_colony(sim, 0)
	var n := 0
	for i in 5:
		for b in sim.buildings.list:
			b.broken = false
		if sim.storyteller.fire("lightning"):
			n += 1
	assert_eq(n, int(sim.defs.events["lightning"]["max_per_game"]))


func test_toxic_fallout_needs_contamination() -> void:
	var sim := _sim()
	assert_false(sim.storyteller.fire("toxic_fallout"), "clean planet")
	sim.contamination.level = sim.defs.balance["contamination"]["max"] * 0.5
	assert_true(sim.storyteller.fire("toxic_fallout"))
	var sick := 0
	for c in sim.colonists.list:
		if c.is_sick(sim.tick):
			sick += 1
	assert_true(sick > 0)


func test_cargo_pod_drops_supplies() -> void:
	var sim := _sim()
	var before := sim.items.count_world("essence_ore")
	assert_true(sim.storyteller.fire("cargo_pod"))
	assert_true(sim.items.count_world("essence_ore") > before)
	assert_eq(sim.items.count_world("essence_ore"), sim.ledger.balance_of("essence_ore"))


func test_generator_deterministic_and_traits() -> void:
	var a := _sim(9)
	var b := _sim(9)
	var ca := ColonistGenerator.generate(a, Vector2i(3, 3))
	var cb := ColonistGenerator.generate(b, Vector2i(3, 3))
	assert_eq(ca.display_name, cb.display_name)
	assert_eq(ca.bio["age"], cb.bio["age"])
	assert_eq(ca.bio["traits"], cb.bio["traits"])
	assert_eq(ca.skills.levels, cb.skills.levels)
	assert_true((ca.bio["traits"] as Array).size() <= 2)


func test_deterministic_long_run() -> void:
	var sums: Array[int] = []
	for i in 2:
		var sim := _sim(12)
		sim.storyteller.fire("wanderer")
		sim.storyteller.fire("cargo_pod")
		sim.run_ticks(3000)
		sums.append(sim.map.checksum() + sim.colonists.alive_count() * 1000 + sim.storyteller.fired.size())
	assert_eq(sums[0], sums[1])
