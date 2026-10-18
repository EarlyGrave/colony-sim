extends TestCase
## F5: outpost Recall button, new-game dialog margins, radial ring vs the belt strip.

var _camps: Array = []


func after_each() -> void:
	for c in _camps:
		c.dispose()
	_camps.clear()
	super.after_each()


func _btns(n: Node, out: Array[Button]) -> void:
	for ch in n.get_children():
		if ch is Button:
			out.append(ch)
		_btns(ch, out)


func _panel_for(id_map_active: bool) -> Array:
	var c := Campaign.new(3, func() -> Node: return make_bus(), peaceful_defs())
	c.start()
	_camps.append(c)
	c.home_sim().research.done.append("expeditions")
	var id := c.add_outpost("ash", [{"name": "Rook"}], {"essence_ore": 40})
	if id_map_active:
		c.switch_map(id)
	var p := ExpeditionPanel.new()
	_owned_nodes.append(p)
	p.setup(c)
	p.open(c.active_sim())
	return [c, p, id]


func test_recall_button_calls_campaign_once() -> void:
	var a := _panel_for(false)
	var c: Campaign = a[0]
	var p: ExpeditionPanel = a[1]
	var id: int = a[2]
	var b := p.content.get_node_or_null("recall_%d" % id) as Button
	assert_true(b != null, "recall button exists")
	assert_true(b.custom_minimum_size.x >= 64 and b.custom_minimum_size.y >= 64)
	assert_false(b.disabled)
	b.pressed.emit()  # asks for confirmation only
	assert_eq(p.recall_calls, 0)
	assert_eq(c.maps.size(), 2)
	var bs: Array[Button] = []
	_btns(p.content, bs)
	for x in bs:
		assert_true(x.custom_minimum_size.y >= 64.0)
	(p.content.find_child("recall_yes_%d" % id, true, false) as Button).pressed.emit()
	assert_eq(p.recall_calls, 1)
	assert_eq(c.maps.size(), 1)
	var returning := 0
	for f: Dictionary in c.in_flight:
		if str(f.get("kind", "")) == "return":
			assert_eq((f["crew"] as Array).size(), 1)
			returning += 1
	assert_eq(returning, 1)


func test_recall_disabled_when_viewing_outpost() -> void:
	var a := _panel_for(true)
	var c: Campaign = a[0]
	var p: ExpeditionPanel = a[1]
	var id: int = a[2]
	assert_true((p.content.get_node("recall_%d" % id) as Button).disabled)
	assert_false(p.do_recall(id))
	assert_eq(c.maps.size(), 2)


func test_new_game_dialog_margin() -> void:
	var meta := MetaState.new()
	var d := NewGameDialog.new(meta)
	_owned_nodes.append(d)
	var pad := d.get_node("Pad") as MarginContainer
	for side in ["left", "top", "right", "bottom"]:
		assert_true(pad.get_theme_constant("margin_" + side) >= 16)
	assert_true(d.start_button.custom_minimum_size.y >= 64.0)


func test_radial_ring_avoids_rects() -> void:
	var r := RadialMenu.new()
	_owned_nodes.append(r)
	var strip := Rect2(88, 250, 520, 70)
	r.avoid_provider = func() -> Array: return [strip]
	for pos: Vector2 in [Vector2(300, 285), Vector2(100, 380), Vector2(844, 390), Vector2(0, 0), Vector2(400, 250)]:
		r.open_at(pos)
		assert_false(r.ring_hits(r.center, [strip]), "ring clear at %s" % pos)
		r.close()
