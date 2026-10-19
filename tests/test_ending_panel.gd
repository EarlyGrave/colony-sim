extends TestCase
## EV: Ending sheet wiring and layout.


func _open(sim: Simulation) -> EndingPanel:
	var p := PanelRegistry.make_panel("ending") as EndingPanel
	assert_true(p != null, "ending registered")
	_owned_nodes.append(p)
	p.open(sim)
	return p


func _btn(p: EndingPanel, nm: String) -> Button:
	return p.content.find_child(nm, true, false) as Button


func test_undecided_has_no_buttons() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	var p := _open(sim)
	assert_true(_btn(p, "StartAssault") == null and _btn(p, "PayFee") == null, "no actions")
	assert_true("Undecided" in (p.content.get_child(0) as Label).text, "undecided shown")


func test_fight_button_disabled_without_uplink() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	assert_true(sim.set_path("fight"), "path set")
	var p := _open(sim)
	var b := _btn(p, "StartAssault")
	assert_true(b != null and b.disabled, "disabled without uplink")
	assert_eq(EndingPanel.assault_block(sim), "Needs a powered Uplink Array")
	assert_true(b.custom_minimum_size.y >= 64.0, "big")


func test_escape_buttons_follow_commands() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	assert_true(sim.set_path("escape"), "path set")
	var p := _open(sim)
	assert_true(_btn(p, "ContactBandits").disabled, "contact needs sales")
	assert_true(_btn(p, "PayFee").disabled, "fee needs contact")
	assert_true(_btn(p, "StartExtraction").disabled, "extraction needs fee")
	sim.contraband.sales = 99
	sim.contraband.escape_credit = 500
	p.refresh()
	var c := _btn(p, "ContactBandits")
	assert_false(c.disabled, "contact enabled")
	c.pressed.emit()
	assert_true(sim.fight_escape.contacted, "contact command ran")
	var f := _btn(p, "PayFee")
	assert_false(f.disabled, "fee enabled")
	f.pressed.emit()
	assert_true(sim.fight_escape.paid, "fee command ran")
	var x := _btn(p, "StartExtraction")
	assert_false(x.disabled, "extraction enabled")
	x.pressed.emit()
	assert_true(sim.fight_escape.counting, "extraction command ran")
	assert_true(p.content.get_node_or_null("CreditBar") != null and p.content.get_node_or_null("SuspicionBar") != null, "bars")


func test_submit_manifest_buttons() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	assert_true(sim.set_path("submit"), "path set")
	var p := _open(sim)
	var seats := sim.shuttle.seats()
	assert_true(_btn(p, "ManifestMinus") != null, "minus")
	_btn(p, "ManifestMinus").pressed.emit()
	assert_eq(sim.shuttle.seats(), seats - 1, "seat removed")
	_btn(p, "ManifestPlus").pressed.emit()
	assert_eq(sim.shuttle.seats(), seats, "seat restored")
