extends TestCase
## E4: petition / dispatch / reviews panels build against the real sim API and a stub.


class StubSim extends RefCounted:
	var delivered := -1
	var shipped := ""
	func get_petition_state() -> Dictionary:
		return {"enabled": true, "phase": 2, "total": 2, "done": 1, "phases": [
			{"phase": 1, "title": "A", "done": true, "required": {}, "delivered": {}, "reward": ""},
			{"phase": 2, "title": "B", "done": false, "reward": "debts -8%", "required": {"plate": 60}, "delivered": {"plate": 5}}]}
	func get_sector_state() -> Dictionary:
		return {"enabled": true, "wave_mult": 1.0, "modifiers": [{"id": "m", "name": "Mod"}], "tiers": [
			{"tier": 1, "name": "T", "done": false, "pick": "", "available": true, "bundle": {"raw_food": 100}, "have": {"raw_food": 100}}]}
	func deliver_petition(i: int) -> bool:
		delivered = i
		return true
	func dispatch_sector(t: int, id: String) -> bool:
		shipped = "%d:%s" % [t, id]
		return true


func test_chip_text() -> void:
	assert_eq(PetitionPanel.chip_text({}), "")
	assert_eq(PetitionPanel.chip_text(StubSim.new().get_petition_state()), "Petition P2/2")


func test_panels_with_real_sim() -> void:
	for on in [false, true]:
		var d := peaceful_defs()
		d.balance["e1_enabled"] = on
		d.balance["e2_enabled"] = on
		var sim := make_sim(5, false, 24, 24, d)
		for id in ["petition", "dispatch", "reviews"]:
			var p := PanelRegistry.make_panel(id)
			assert_true(p != null)
			_owned_nodes.append(p)
			p.open(sim)
			p.refresh()


func test_panels_with_stub() -> void:
	var st := StubSim.new()
	var pp := PetitionPanel.new()
	_owned_nodes.append(pp)
	pp.api = st
	pp.refresh()
	var dp := DispatchPanel.new()
	_owned_nodes.append(dp)
	dp.api = st
	dp.refresh()
	var found := 0
	for b in pp.find_children("*", "Button", true, false):
		if (b as Button).text == "Deliver":
			assert_true((b as Button).custom_minimum_size.y >= 64.0)
			(b as Button).pressed.emit()
			found += 1
	assert_eq(found, 1)
	assert_eq(st.delivered, 2)
	for b in dp.find_children("*", "Button", true, false):
		if (b as Button).text == "Ship: Mod":
			(b as Button).pressed.emit()
	assert_eq(st.shipped, "1:m")
