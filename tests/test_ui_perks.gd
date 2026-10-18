extends TestCase


func _panel(sim: Simulation, cid: int) -> PerkPanel:
	var p := PanelRegistry.make_panel("perks") as PerkPanel
	_owned_nodes.append(p)
	p.focus_colonist(cid)
	p.open(sim)
	return p


func _first_perk(sim: Simulation, skill: String) -> String:
	return sim.perks.perks_of_skill(skill)[0]


func test_panel_builds_and_lists_nodes() -> void:
	var sim := make_sim(5)
	var c: Colonist = sim.colonists.list[0]
	var p := _panel(sim, c.id)
	assert_true(p.content.get_child_count() > 3, "panel has content")
	assert_true(p._tree != null and p._tree.get_child_count() > 0, "tree nodes drawn")


func test_learn_through_ui_handler_uses_sim_command() -> void:
	var sim := make_sim(5)
	var c: Colonist = sim.colonists.list[0]
	var skill := "mining"
	c.skills.join_levels.clear()  # tests grant levels directly: baseline 0 (generated join levels depend on the seed)
	c.skills.levels[skill] = 4
	var pid := _first_perk(sim, skill)
	var p := _panel(sim, c.id)
	p.skill = skill
	p.selected_perk = pid
	p._key = ""
	p.refresh()
	assert_eq(p.state_of_perk(c, pid), "available")
	assert_false(p.on_learn_pressed(), "first tap only arms the confirm")
	assert_false(sim.perks.has(c, pid))
	assert_true(p.on_learn_pressed(), "second tap learns")
	assert_true(sim.perks.has(c, pid))
	assert_eq(p.state_of_perk(c, pid), "learned")


func test_locked_perk_cannot_be_learned() -> void:
	var sim := make_sim(5)
	var c: Colonist = sim.colonists.list[0]
	c.skills.levels["mining"] = 0
	var pid := _first_perk(sim, "mining")
	var p := _panel(sim, c.id)
	p.skill = "mining"
	p.selected_perk = pid
	p._confirm = true
	assert_false(p.on_learn_pressed())
	assert_false(sim.perks.has(c, pid))


func test_view_never_mutates_perks_directly() -> void:
	var out: Array = []
	for f in ["res://view/panels/perk_panel.gd", "res://view/panels/sections/perks_section.gd",
			"res://view/panels/colonist_bar.gd"]:
		var txt := FileAccess.get_file_as_string(f)
		for line in txt.split("\n"):
			if (".perks.learned.append" in line or ".perks.learned.clear" in line
					or ".perks.cooldowns[" in line or ".perks.buffs[" in line or ".perks.learned =" in line):
				out.append(f + ": " + line)
	assert_eq(out.size(), 0, "direct perk mutation in view: " + str(out))


func test_letter_for_point_has_panel_link() -> void:
	var sim := make_sim(5)
	var letters := LetterLog.new()
	letters.bind(sim, sim.bus)
	var c: Colonist = sim.colonists.list[0]
	sim.bus.perk_point_available.emit(c.id, "mining", 1)
	assert_true(letters.entries.size() >= 1)
	assert_eq(letters.entries[0].get("panel"), "perks")
	assert_true(c.display_name in str(letters.entries[0]["text"]))
	letters.unbind()
