extends TestCase
## B5: squad tuning target, wave_report signal, report card text.

const Model := preload("res://tools/combat_model.gd")


func test_squad_cuts_damage_by_30_percent() -> void:
	assert_true(Model.squad_damage_delta(Defs.get_default()) <= -0.30, "squad delta")


func test_card_reports_wave_end_and_emits_signal() -> void:
	var sim := make_sim(5, false, 30, 30, peaceful_defs())
	var card := WaveReportCard.new()
	_owned_nodes.append(card)
	card.bind(sim)
	var got: Array = []
	sim.bus.wave_report.connect(func(r: Dictionary) -> void: got.append(r))
	sim.bus.wave_incoming.emit(Vector2i(0, 5), 120)
	card.refresh()
	assert_true(card.visible, "ETA marker shown")
	assert_true(card.text_now().begins_with("Wave from"), card.text_now())
	sim.bus.wave_started.emit(1, 3.0)
	sim.bus.enemy_killed.emit(1)
	sim.bus.wave_ended.emit(1)
	assert_eq(got.size(), 1)
	assert_eq(int(got[0]["kills"]), 1)
	assert_true(card.text_now().begins_with("Wave 1 over"), card.text_now())
