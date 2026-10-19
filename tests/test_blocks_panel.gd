extends TestCase
## N4: Blocks panel rows, trend, notifications, informant/stash rows, inspector line.


func _open(sim: Simulation) -> BlocksPanel:
	var p := PanelRegistry.make_panel("blocks") as BlocksPanel
	assert_true(p != null, "blocks registered")
	_owned_nodes.append(p)
	p.open(sim)
	return p


func test_five_rows_and_standing_update() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	var p := _open(sim)
	for b in ["lifer", "clerk", "zealot", "informant", "fresh_fish"]:
		var row := p.content.get_node_or_null("Row_" + b)
		assert_true(row != null, "row " + b)
		assert_true((row.get_child(0) as Button).custom_minimum_size.y >= 64.0, "row height")
	sim.blocks._change("lifer", -12.0, true)
	p.refresh()
	assert_true("38" in ((p.content.get_node("Row_lifer").get_child(0)) as Button).text, "standing shown")
	assert_true("v" in p.row_text("lifer"), "trend arrow down")


func test_notice_threshold() -> void:
	assert_eq(BlocksPanel.notice_text("Lifers", 50.0, 45.0), "")
	assert_true(BlocksPanel.notice_text("Lifers", 50.0, 38.0) != "")


func test_informant_row_and_highlight() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	var p := _open(sim)
	var got: Array = []
	p.members_highlighted.connect(func(ids: Array) -> void: got.append(ids))
	var b := sim.blocks.block_of(sim.colonists.list[0])
	p.highlight(b)
	assert_eq(got.size(), 1, "highlight emits")
	assert_eq(BlocksPanel.leaning_for(sim, "lifer"), "", "no leaning before Q14")
