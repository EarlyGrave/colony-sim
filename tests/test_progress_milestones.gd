extends TestCase


func test_milestone_letters_only_at_3_6_10() -> void:
	var sim := make_sim(7)
	var c: Colonist = sim.colonists.list[0]
	c.skills.join_levels.clear()
	var letters: Array = []
	sim.bus.letter_received.connect(func(t: String, _x: String) -> void: letters.append(t))
	c.skills.levels["mining"] = 0
	sim.progression.award(c, "mining", 1000000.0, "test")
	assert_eq(sim.progression.milestones, 3)  # one big award passes L3, L6, L10
	assert_eq(letters.size(), 3)


func test_non_milestone_level_no_letter() -> void:
	var sim := make_sim(7)
	var n := [0]
	sim.bus.letter_received.connect(func(_t: String, _x: String) -> void: n[0] += 1)
	sim.bus.skill_leveled.emit(sim.colonists.list[0].id, "mining", 4)
	assert_eq(n[0], 0)
	sim.bus.skill_leveled.emit(sim.colonists.list[0].id, "mining", 6)
	assert_eq(n[0], 1)
	assert_eq(sim.progression.milestones, 1)


func test_dossier_traits_roundtrip() -> void:
	var sim := make_sim(7)
	var c: Colonist = sim.colonists.list[0]
	c.bio["traits"] = ["strong", "hardened"]
	c.skills.levels["mining"] = 20
	var snap := Legacy.ng_snapshot(sim, "win")
	var ms := MetaState.new(sim.defs)
	ms.finish_sentence(snap)
	assert_true((ms.ng["dossier"]["traits"] as Array).has("hardened"))
	var o := ms.make_ng_opts()["opts"] as Dictionary
	var sim2 := make_sim(7)
	var v: Colonist = sim2.colonists.list[0]
	v.bio["traits"] = []
	StartOpts.apply(sim2, o)
	assert_true((v.bio["traits"] as Array).has("hardened"))
