extends TestCase
## R3: sentence_min / carry_debt triggers, Q11, Q12.

const Q11 := "q11_previous_tenant"
const Q12 := "q12_rolled_over"


func _sim(sentence: int, carry: int, seed_value := 5) -> Simulation:
	var o := {"sentence": sentence}
	if carry > 0:
		o["carry_debt"] = carry
	var sim := Simulation.new(seed_value, make_bus(), peaceful_defs(), o)
	sim.start_new_game()
	_sims.append(sim)
	return sim


func _trig(sim: Simulation, q: String) -> bool:
	return sim.quests._trigger_ok(sim.defs.quests[q]["trigger"])


func test_sentence_gating() -> void:
	var s1 := _sim(1, 0)
	assert_true(s1.defs.quests.has(Q11))
	s1.tick = 20 * 86400
	assert_false(_trig(s1, Q11))
	assert_false(_trig(s1, Q12))
	var s2 := _sim(2, 100)
	s2.tick = 20 * 86400
	assert_true(_trig(s2, Q11))
	assert_false(_trig(s2, Q12))


func test_q12_needs_q11_and_debt() -> void:
	var s3 := _sim(3, 100)
	s3.tick = 20 * 86400
	assert_false(_trig(s3, Q12))
	s3.quests.quests[Q11] = {"state": "done", "refs": {}}
	assert_true(_trig(s3, Q12))
	var s3b := _sim(3, 0)
	s3b.tick = 20 * 86400
	s3b.quests.quests[Q11] = {"state": "done", "refs": {}}
	assert_false(_trig(s3b, Q12))


func test_contest_deterministic() -> void:
	var outs: Array = []
	for i in 2:
		var s := _sim(3, 400, 9)
		var fx: Array = s.defs.quests[Q12]["beats"]["clause"]["options"]["contest"]["effects"]
		s.quests._apply_effects(Q12, fx.slice(1))
		var tot := 0
		for c in s.colonists.list:
			var st := s.debt.state_of(c)
			if st != null:
				tot += st.total
		outs.append(tot)
	assert_eq(outs[0], outs[1])
