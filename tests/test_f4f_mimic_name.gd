extends TestCase
## F4f: a mimic shows the name of the dead inmate it wears, only after Q15 (clue_our_dead).


func _rig() -> Array:
	var d := TestCase.peaceful_defs()
	d.balance["q_enabled"] = true
	var sim := make_sim(5, false, 30, 30, d)
	var c: Colonist = sim.colonists.spawn(Vector2i(4, 4))
	sim.colonists.spawn(Vector2i(5, 4))
	sim.colonists.kill(c)
	var feed := FeedTicker.new()
	var pa := PaBanner.new()
	_owned_nodes.append(feed)
	_owned_nodes.append(pa)
	var dir := FeedDirector.new(feed, pa)
	dir.bind(sim)
	return [sim, c, feed, dir]


func test_no_name_before_flag() -> void:
	var r := _rig()
	var sim: Simulation = r[0]
	var e: Enemy = sim.threats._spawn("mimic", Vector2i(10, 10))
	assert_eq(MimicFace.worn_name(sim, e), "")
	assert_eq(MimicFace.inspect_line(sim, e, FlavorPicker.load_default()), "")
	sim.threats.damage_enemy(e, 9999.0)
	for t in (r[2] as FeedTicker).texts():
		assert_false((r[1] as Colonist).display_name in t)


func test_name_after_flag() -> void:
	var r := _rig()
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	sim.quests.set_flag("clue_our_dead")
	var e: Enemy = sim.threats._spawn("mimic", Vector2i(10, 10))
	assert_eq(MimicFace.worn_name(sim, e), c.display_name)
	var line := MimicFace.inspect_line(sim, e, FlavorPicker.load_default())
	assert_eq(line, "Mimic — wears the face of %s" % c.display_name)
	sim.threats.damage_enemy(e, 9999.0)
	assert_true(("%s is gone for good." % c.display_name) in (r[2] as FeedTicker).texts())


func test_other_creatures_never_named() -> void:
	var r := _rig()
	var sim: Simulation = r[0]
	sim.quests.set_flag("clue_our_dead")
	var e: Enemy = sim.threats._spawn("crawler", Vector2i(10, 10))
	assert_eq(MimicFace.worn_name(sim, e), "")
