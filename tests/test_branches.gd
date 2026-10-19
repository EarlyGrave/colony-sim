extends TestCase
## PW4: skill specialisation branches.


func _sim() -> Simulation:
	return make_sim(9, false, 24, 24, peaceful_defs())


func test_eligibility() -> void:
	var sim := _sim()
	var c: Colonist = sim.colonists.spawn(Vector2i(5, 5))
	c.skills.levels["shooting"] = 4
	assert_false(sim.choose_branch(c.id, "shooting", "marksman"), "level too low")
	c.skills.levels["shooting"] = 5
	assert_false(sim.choose_branch(c.id, "shooting", "warrior"), "wrong skill branch")
	assert_true(sim.choose_branch(c.id, "shooting", "marksman"), "ok")
	assert_false(sim.choose_branch(c.id, "shooting", "gunner"), "only one")
	assert_eq(sim.perks.branch_of(c, "shooting"), "marksman")


func test_effects_read_through_mod() -> void:
	var sim := _sim()
	var c: Colonist = sim.colonists.spawn(Vector2i(5, 5))
	assert_eq(sim.perks.mod(c, "hit_chance"), 0.0, "none by default")
	c.skills.levels["shooting"] = 5
	c.skills.levels["melee"] = 5
	sim.choose_branch(c.id, "shooting", "marksman")
	sim.choose_branch(c.id, "melee", "monk")
	assert_true(sim.perks.mod(c, "hit_chance") > 0.1, "marksman hit")
	assert_true(sim.perks.mod(c, "crit_chance") > 0.0, "marksman crit")
	assert_true(sim.perks.mod(c, "unarmed_damage") > 0.0, "monk")
	assert_eq(sim.perks.mod(c, "burst_shots"), 0.0, "gunner not chosen")


func test_digger_speeds_mining() -> void:
	var sim := _sim()
	var c: Colonist = sim.colonists.spawn(Vector2i(5, 5))
	c.skills.levels["mining"] = 5
	var base := sim.perks.mod(c, "mining_speed")
	sim.choose_branch(c.id, "mining", "digger")
	assert_true(sim.perks.mod(c, "mining_speed") > base, "digger")


func test_deterministic() -> void:
	var out: Array = []
	for i in 2:
		var sim := _sim()
		var c: Colonist = sim.colonists.spawn(Vector2i(5, 5))
		c.skills.levels["melee"] = 6
		sim.choose_branch(c.id, "melee", "warrior")
		for t in 200:
			sim.step()
		out.append([sim.perks.mod(c, "melee_damage"), sim.rng.randi()])
	assert_eq(out[0], out[1], "same seed same result")


func test_ui_section_pick_button() -> void:
	var sim := _sim()
	var c: Colonist = sim.colonists.spawn(Vector2i(5, 5))
	c.skills.levels["plants"] = 5
	var sec: Object = load("res://view/panels/sections/perks_section.gd").new()
	var box := VBoxContainer.new()
	_owned_nodes.append(box)
	sec.build(sim, {"colonist": c}, box)
	var found: Button = null
	for ch in box.get_children():
		if ch is Button and ch.has_meta("branch_id") and ch.get_meta("branch_id") == "farmer":
			found = ch
	assert_true(found != null, "pick button shown")
	found.pressed.emit()
	assert_eq(sim.perks.branch_of(c, "plants"), "farmer")
	var box2 := VBoxContainer.new()
	_owned_nodes.append(box2)
	sec.build(sim, {"colonist": c}, box2)
	for ch in box2.get_children():
		assert_false(ch is Button and ch.has_meta("branch_id"), "no buttons after pick")
