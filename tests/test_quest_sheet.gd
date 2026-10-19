extends TestCase
## QU: quest sheet shows title, Warden text, option hints, disabled state, and toasts a choice.


func _sheet(offer_quest: String) -> Array:
	var d := peaceful_defs()
	d.balance["q_enabled"] = true
	var sim := make_sim(5, false, 30, 30, d)
	sim.colonists.spawn(Vector2i(4, 4))
	var sh := QuestSheet.new()
	sh.bind(sim)
	match offer_quest:
		"q6":
			sim.quests.start("q6_auditor")
			sim.run_ticks(sim.ticks_per_day + 5)
		"q2":
			sim.q2_pilgrims.begin()
		"q1":
			var o: Dictionary = sim.q1_clerk.cfg["beats"]["offer"]
			sim.quests.start("q1")
			sim.quests.offer("q1", "offer", "Offer text", o["options"])
	return [sim, sh]


func _buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button:
			out.append(c)
		_buttons(c, out)


func _texts(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Label:
			out.append((c as Label).text)
		_texts(c, out)


func test_q6_title_options_hints_and_disabled() -> void:
	var r := _sheet("q6")
	var sh: QuestSheet = r[1]
	var txt: Array = []
	_texts(sh, txt)
	var all := "\n".join(PackedStringArray(txt))
	assert_true(all.find("Auditor Visit") >= 0, "title from data")
	assert_true(all.find("q6_auditor") < 0, "no raw id")
	assert_true(all.find("Warden:") >= 0, "warden text")
	var bs: Array = []
	_buttons(sh, bs)
	assert_eq(bs.size(), 4, "head + 3 options")
	for b: Button in bs:
		assert_true(b.custom_minimum_size.y >= 64.0, "button >= 64")
	var hide: Button = bs[1]
	assert_true(hide.disabled, "plate requirement unmet")
	assert_true(hide.text.find("Needs 30 plate") >= 0, hide.text)
	assert_true(hide.text.find("Waves +20%") >= 0, "hint shown")
	sh.free()


func test_code_quests_show_offers() -> void:
	for q in ["q1", "q2"]:
		var r := _sheet(q)
		var bs: Array = []
		_buttons(r[1], bs)
		assert_eq(bs.size(), 4, q + " head + 3 options")
		assert_true((bs[1] as Button).text.find("\n") > 0, q + " hint line")
		r[1].free()


func test_announce_beat_has_progress_no_buttons() -> void:
	var d := peaceful_defs()
	d.balance["q_enabled"] = true
	var sim := make_sim(5, false, 30, 30, d)
	var sh := QuestSheet.new()
	sh.bind(sim)
	sim.quests.start("q6_auditor")
	assert_eq(sh.progress_of("q6_auditor"), "Beat 1/2")
	var bs: Array = []
	_buttons(sh, bs)
	assert_eq(bs.size(), 1, "header only")
	sh.free()


func test_choice_signal() -> void:
	var d := peaceful_defs()
	d.balance["q_enabled"] = true
	var sim := make_sim(5, false, 30, 30, d)
	var sh := QuestSheet.new()
	sh.bind(sim)
	var got: Array = []
	sh.choice_posted.connect(func(t: String) -> void: got.append(t))
	sim.quests.start("q6_auditor")
	sim.run_ticks(sim.ticks_per_day + 5)
	assert_eq(got.size(), 1)
	assert_true(str(got[0]).find("Auditor Visit") >= 0)
	sh.free()
