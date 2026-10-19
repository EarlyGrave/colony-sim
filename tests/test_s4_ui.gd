extends TestCase
## S4: shuttle / beacon panels and HUD chips; build with keys off/on and with a stub.


class StubSim extends RefCounted:
	var launched := false
	var ticks_per_day := 1200
	func get_shuttle_state() -> Dictionary:
		return {"phase": "ready", "parts": 10, "need": 10, "t_left": 0, "hp": 80, "hp_max": 100}
	func launch_shuttle() -> bool:
		launched = true
		return true
	func get_beacon_state() -> Dictionary:
		return {"alive": 3, "next_decay": 1800, "debt_rate_cut": 0.15}


func test_chip_text() -> void:
	assert_eq(ShuttlePanel.chip_text({}), "")
	assert_eq(ShuttlePanel.chip_text({"phase": "locked"}), "")
	assert_eq(ShuttlePanel.chip_text({"phase": "building", "parts": 40, "need": 100}), "Shuttle 40/100")
	assert_eq(ShuttlePanel.chip_text({"phase": "countdown", "t_left": 1800}, 1200), "Launch in 1d 12h")


func test_panels_real_sim() -> void:
	for on in [false, true]:
		var d := peaceful_defs()
		d.balance["s1_enabled"] = on
		d.balance["s2_enabled"] = on
		var sim := make_sim(5, false, 24, 24, d)
		for id in ["shuttle", "beacons"]:
			var p := PanelRegistry.make_panel(id)
			assert_true(p != null)
			_owned_nodes.append(p)
			p.open(sim)
			p.refresh()


func test_panels_stub() -> void:
	var st := StubSim.new()
	var sp := ShuttlePanel.new()
	_owned_nodes.append(sp)
	sp.api = st
	sp.refresh()
	var n := 0
	for b in sp.find_children("*", "Button", true, false):
		if (b as Button).text == "Launch":
			assert_true((b as Button).custom_minimum_size.y >= 64.0)
			(b as Button).pressed.emit()
			n += 1
	assert_eq(n, 1)
	assert_true(st.launched)
	var bp := BeaconPanel.new()
	_owned_nodes.append(bp)
	bp.api = st
	bp.refresh()
