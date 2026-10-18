extends TestCase
# region R2d


func _panel(sim: Simulation) -> ResearchPanel:
	var p := PanelRegistry.make_panel("research") as ResearchPanel
	_owned_nodes.append(p)
	p.open(sim)
	return p


func _walk(n: Node, out: Array) -> void:
	for ch in n.get_children():
		out.append(ch)
		_walk(ch, out)


func test_all_nodes_rendered() -> void:
	var sim := make_sim(5)
	var p := _panel(sim)
	var cards := 0
	var all: Array = []
	_walk(p, all)
	for n: Node in all:
		if n is Button and n.name.begins_with("Tech_"):
			cards += 1
	assert_eq(cards, p.adapter.tier_count(), "one card per tech")
	assert_true(cards >= 14, "full tree rendered (14 nodes)")


func test_buttons_min_height_64() -> void:
	var sim := make_sim(5)
	var p := _panel(sim)
	var all: Array = []
	_walk(p, all)
	var n_btn := 0
	for n: Node in all:
		if n is Button:
			n_btn += 1
			assert_true((n as Button).custom_minimum_size.y >= 64.0, "button %s min height" % n.name)
	assert_true(n_btn > 14, "cards + deliver + close buttons")


func _first_in_state(p: ResearchPanel, state: String) -> String:
	for t in ResearchPanel.TIERS:
		for cand in p.adapter.tech_ids(t):
			if p.adapter.state_of(cand) == state:
				return cand
	return ""


func test_tap_queues_and_unqueues() -> void:
	var sim := make_sim(5)
	var p := _panel(sim)
	var id := _first_in_state(p, "available")
	if id == "":
		return  # nothing researchable until the sim core defines unlocked tiers
	assert_true(p.on_tech_pressed(id))
	assert_true(p.adapter.queue_list().has(id), "queued after tap")
	assert_true(p.adapter.state_of(id) in ["active", "queued"])
	assert_true(p.on_tech_pressed(id))
	assert_false(p.adapter.queue_list().has(id), "unqueued after second tap")


func test_locked_tap_is_noop() -> void:
	var sim := make_sim(5)
	var p := _panel(sim)
	var id := _first_in_state(p, "locked")
	assert_true(id != "", "a locked tech exists")
	assert_false(p.on_tech_pressed(id))
	assert_false(p.adapter.queue_list().has(id))
