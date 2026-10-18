extends TestCase
## C1 squads: form / hold / focus / disband, role affinity, death, determinism.


func _scene(seed_value := 3) -> Simulation:
	return make_sim(seed_value, false, 40, 40, peaceful_defs())


func _inmates(sim: Simulation, n: int) -> Array:
	var ids: Array = []
	for i in n:
		var c := sim.colonists.spawn(Vector2i(5 + i, 5))
		c.bio["traits"] = []
		ids.append(c.id)
	return ids


func test_form_four_drafts_and_fifth_rejected() -> void:
	var sim := _scene()
	var ids := _inmates(sim, 5)
	var sid := sim.form_squad(ids.slice(0, 4), ["bulwark", "lancer", "medic", "lancer"])
	assert_true(sid > 0)
	for id: int in ids.slice(0, 4):
		assert_true(sim.colonists.get_by_id(id).combat.drafted)
	assert_eq(sim.form_squad(ids, []), -1, "5 members rejected")
	assert_eq(sim.form_squad([ids[4]] + [ids[0]], []), -1, "already squadded rejected")
	assert_eq(sim.form_squad([ids[4]], ["wizard"]), -1, "bad role rejected")
	assert_false(sim.colonists.get_by_id(ids[4]).combat.drafted)


func test_hold_gets_everyone_near_offsets() -> void:
	var sim := _scene()
	var ids := _inmates(sim, 4)
	var sid := sim.form_squad(ids, ["bulwark", "lancer", "medic", "lancer"])
	var anchor := Vector2i(20, 20)
	assert_true(sim.squad_hold(sid, anchor))
	sim.run_ticks(60)
	var sq := sim.squads.get_squad(sid)
	for id: int in ids:
		var c := sim.colonists.get_by_id(id)
		var off: Array = sim.defs.roles["roles"][sq.role_of[id]]["formation_offset"]
		var want := anchor + Vector2i(int(off[0]), int(off[1]))
		assert_true(maxi(absi(c.cell.x - want.x), absi(c.cell.y - want.y)) <= 2, "member %d at %s want %s" % [id, c.cell, want])


func test_focus_targets_all_but_medic() -> void:
	var sim := _scene()
	var ids := _inmates(sim, 3)
	var sid := sim.form_squad(ids, ["bulwark", "lancer", "medic"])
	var e := sim.threats._spawn("crawler", Vector2i(30, 30))
	assert_true(sim.squad_focus(sid, e.id))
	sim.run_ticks(2)
	assert_eq(sim.colonists.get_by_id(ids[0]).combat.target_id, e.id)
	assert_eq(sim.colonists.get_by_id(ids[1]).combat.target_id, e.id)
	assert_eq(sim.colonists.get_by_id(ids[2]).combat.target_id, -1, "medic ignores focus")
	assert_false(sim.squad_focus(sid, 99999), "unknown enemy rejected")


func test_disband_clears_drafted_and_restores_weapon() -> void:
	var sim := _scene()
	var ids := _inmates(sim, 2)
	var before: String = sim.colonists.get_by_id(ids[0]).combat.weapon
	var sid := sim.form_squad(ids, ["lancer", "medic"])
	assert_eq(sim.colonists.get_by_id(ids[0]).combat.weapon, "rifle")
	assert_true(sim.disband_squad(sid))
	for id: int in ids:
		assert_false(sim.colonists.get_by_id(id).combat.drafted)
	assert_eq(sim.colonists.get_by_id(ids[0]).combat.weapon, before)
	assert_false(sim.disband_squad(sid))


func test_role_affinity_suggests_roles() -> void:
	var sim := _scene()
	var ids := _inmates(sim, 3)
	var a := sim.colonists.get_by_id(ids[0])
	var b := sim.colonists.get_by_id(ids[1])
	var c := sim.colonists.get_by_id(ids[2])
	for x in [a, b, c]:
		for s in ["melee", "shooting", "medicine"]:
			x.skills.levels[s] = 0
	a.skills.levels["shooting"] = 6  # sharpshooter
	b.bio["traits"] = ["careful"]  # medic by trait
	c.skills.levels["melee"] = 5  # brawler
	assert_eq(sim.squads.suggest_roles(ids), ["lancer", "medic", "bulwark"] as Array[String])
	var sid := sim.form_squad(ids, [])
	var sq := sim.squads.get_squad(sid)
	assert_eq(sq.role_of[ids[0]], "lancer")
	assert_eq(sq.role_of[ids[1]], "medic")
	assert_eq(sq.role_of[ids[2]], "bulwark")


func test_dead_member_leaves_squad() -> void:
	var sim := _scene()
	var ids := _inmates(sim, 2)
	var sid := sim.form_squad(ids, [])
	sim.colonists.kill(sim.colonists.get_by_id(ids[0]))
	var sq := sim.squads.get_squad(sid)
	assert_eq(sq.members, [ids[1]] as Array[int])
	sim.colonists.kill(sim.colonists.get_by_id(ids[1]))
	assert_true(sim.squads.get_squad(sid) == null, "empty squad dissolves")


func test_manual_order_still_works_for_squad_member() -> void:
	var sim := _scene()
	var ids := _inmates(sim, 2)
	sim.form_squad(ids, [])
	assert_true(sim.order_move(ids[0], Vector2i(10, 10)))


func test_plain_draft_path_without_squad() -> void:
	var sim := _scene()
	var ids := _inmates(sim, 1)
	assert_true(sim.set_drafted(ids[0], true))
	assert_true(sim.squads.list.is_empty())
	assert_true(sim.order_move(ids[0], Vector2i(12, 12)))


func _run_scenario() -> int:
	var sim := _scene(7)
	var ids := _inmates(sim, 3)
	var sid := sim.form_squad(ids, [])
	sim.squad_hold(sid, Vector2i(15, 15))
	sim.run_ticks(50)
	var e := sim.threats._spawn("crawler", Vector2i(22, 15))
	sim.squad_focus(sid, e.id)
	sim.run_ticks(150)
	return SaveGame.state_hash(sim)


func test_same_commands_same_hash() -> void:
	assert_eq(_run_scenario(), _run_scenario())


func test_hash_unchanged_without_squad() -> void:
	var sim := _scene()
	_inmates(sim, 2)
	var h := SaveGame.state_hash(sim)
	var sim2 := _scene()
	_inmates(sim2, 2)
	assert_eq(SaveGame.state_hash(sim2), h)
	sim2.form_squad([1], [])
	assert_true(SaveGame.state_hash(sim2) != h)


func test_save_replay_roundtrip() -> void:
	var sim := _scene()
	var ids := _inmates(sim, 2)
	var sid := sim.form_squad(ids, [])
	sim.squad_hold(sid, Vector2i(14, 14))
	assert_eq(sim.command_log[0][1], "form_squad")
	assert_eq(sim.command_log[0][2][0], "[%d,%d]" % [ids[0], ids[1]])
