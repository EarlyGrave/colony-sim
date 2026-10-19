extends TestCase
## N2: Next Sentence UI. Uses a fixture dict for the N1 `ng` block.

const NG := {"sentence": 2, "carry_debt": 450,
	"dossier": {"name": "Vex", "skills": {"mining": 6, "build": 2, "cook": 4, "haul": 1}, "perk_id": "iron_back"},
	"techs": ["drill", "belt"], "history": [{"n": 1, "seed": 5, "days": 30, "debt_paid": 10, "preset": "standard_term", "result": "shuttle"}]}


func test_card_text() -> void:
	var t := DossierCard.card_text(NG)
	assert_true(t.contains("Veteran: Vex"))
	assert_true(t.contains("Mining 6, Cook 4, Build 2"))
	assert_true(t.contains("Carried debt: 450"))
	assert_true(t.contains("drill, belt"))


func test_win_screen_signal_and_height() -> void:
	var w := WinScreen.new({}, "", NG)
	var got := [0]
	w.next_sentence_pressed.connect(func() -> void: got[0] += 1)
	w.next_button.pressed.emit()
	assert_eq(got[0], 1)
	assert_true(w.next_button.custom_minimum_size.y >= 64.0)
	assert_true(WinScreen.carry_lines(NG)[0].contains("450"))
	w.free()


func test_visibility_rules() -> void:
	var m := MetaState.new()
	assert_false(m.has_ng_carry())
	m.ng["sentence"] = 2
	assert_true(m.has_ng_carry())
	assert_true(MetaScreen.history_line(NG["history"][0]).contains("30 days"))


func test_real_carry_from_snapshot() -> void:
	var sim := make_sim(7)
	var snap := Legacy.ng_snapshot(sim, "shuttle", "standard_term")
	var m := MetaState.new()
	m.finish_sentence(snap)
	var want := roundi(int(snap["debt_left"]) * float(m.ng_cfg()["debt_carry_frac"]))
	assert_eq(m.ng["carry_debt"], want)
	assert_true(WinScreen.carry_lines(m.ng)[0].contains(str(want)))
