extends TestCase
## E4: petition / dispatch / reviews panels build with the sim API absent and with a stub.


class StubSim extends RefCounted:
	var delivered := -1
	var picked := ""
	func petition_state() -> Dictionary:
		return {"enabled": true, "phase": 1, "phases": [
			{"title": "A", "done": true, "items": []},
			{"title": "B", "done": false, "reward": "x", "items": [{"item": "plate", "have": 5, "need": 60}]}]}
	func dispatch_state() -> Dictionary:
		return {"enabled": true, "tiers": [{"title": "T", "done": true, "picked": "", "choices": [{"id": "m", "label": "Mod"}]}]}
	func deliver_petition(i: int) -> void:
		delivered = i
	func pick_dispatch_modifier(_i: int, id: String) -> void:
		picked = id


func test_chip_text() -> void:
	assert_eq(PetitionPanel.chip_text({}), "")
	assert_eq(PetitionPanel.chip_text(StubSim.new().petition_state()), "Petition P2/2")


func test_panels_without_api() -> void:
	var sim := make_sim(5, false, 24, 24, peaceful_defs())
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
	assert_eq(st.delivered, 1)
	for b in dp.find_children("*", "Button", true, false):
		if (b as Button).text == "Mod":
			(b as Button).pressed.emit()
	assert_eq(st.picked, "m")
