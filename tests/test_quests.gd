extends TestCase
## Q0 QuestLog: gating, determinism, N-way answers, mod expiry, debt cap.

const SELFTEST := {
	"trigger": {"min_day": 1},
	"beats": {
		"start": {"text": "Test dispatch.", "options": {
			"a": {"label": "A", "effects": [{"verb": "flag", "id": "took_a"}, {"verb": "mod", "name": "wave_mult", "value": 0.5, "days": 1.0}]},
			"b": {"label": "B", "effects": [{"verb": "debt_pct", "pct": -50.0}], "then": "after"},
			"c": {"label": "C", "requires": {"item": "steel_plate", "n": 99999}}}},
		"after": {"text": "Later.", "delay_days": 1.0}
	}
}


func _defs(enabled := true) -> Defs:
	var d := TestCase.peaceful_defs()
	d.balance["q_enabled"] = enabled
	d.quests = {"q_selftest": SELFTEST.duplicate(true)}
	return d


func _sim(seed_value := 3, enabled := true) -> Simulation:
	return make_sim(seed_value, true, 24, 24, _defs(enabled))


func _run_to_offer(sim: Simulation) -> void:
	var g := 0
	while sim.quests.pending.is_empty() and g < 5 * sim.ticks_per_day:
		sim.step()
		g += 1


func test_disabled_is_inert() -> void:
	var a := _sim(3, false)
	var b := make_sim(3, true, 24, 24, TestCase.peaceful_defs())
	a.run_ticks(a.ticks_per_day * 3)
	b.run_ticks(b.ticks_per_day * 3)
	assert_eq(a.quests.state("q_selftest"), "idle")
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b), "flag off: hash unchanged")
	assert_true(a.quests.state_parts().is_empty())


func test_fires_and_n_way_answer() -> void:
	var sim := _sim()
	_run_to_offer(sim)
	assert_eq(sim.quests.state("q_selftest"), "active")
	var p: Dictionary = sim.quests.pending[0]
	assert_eq(p["options"].size(), 3)
	assert_true(not sim.answer_quest(int(p["uid"]), "c"), "disabled option refused")
	assert_true(not sim.answer_quest(999, "a"), "unknown uid")
	assert_true(sim.answer_quest(int(p["uid"]), "a"))
	assert_true(sim.quests.flag("took_a"))
	assert_eq(sim.quests.state("q_selftest"), "done")
	assert_true(sim.quests.pending.is_empty())


func test_mod_expiry_and_wave_hook() -> void:
	var sim := _sim()
	_run_to_offer(sim)
	sim.answer_quest(int(sim.quests.pending[0]["uid"]), "a")
	assert_eq(sim.quests.mod("wave_mult"), 0.5)
	assert_eq(sim.quests.mod("fine_pct"), 0.0)
	sim.run_ticks(sim.ticks_per_day + 2)
	assert_eq(sim.quests.mod("wave_mult"), 1.0, "expired")


func test_debt_cut_clamped_and_followup_beat() -> void:
	var sim := _sim()
	_run_to_offer(sim)
	var before := 0
	for c in sim.colonists.list:
		before += sim.debt.state_of(c).remaining()
	sim.answer_quest(int(sim.quests.pending[0]["uid"]), "b")
	var after := 0
	for c in sim.colonists.list:
		after += sim.debt.state_of(c).remaining()
	assert_true(after >= int(before * 0.98) - 1, "cut at most ~2%%: %d -> %d" % [before, after])
	assert_eq(sim.quests.state("q_selftest"), "active", "follow-up beat pending")
	sim.run_ticks(sim.ticks_per_day + 5)
	assert_eq(sim.quests.state("q_selftest"), "done")


func test_determinism() -> void:
	var s1 := _sim(5)
	var s2 := _sim(5)
	for s in [s1, s2]:
		_run_to_offer(s)
		s.answer_quest(int(s.quests.pending[0]["uid"]), "b")
		s.run_ticks(s.ticks_per_day * 3)
	assert_eq(s1.quests.log, s2.quests.log)
	assert_eq(SaveGame.state_hash(s1), SaveGame.state_hash(s2))
	assert_true(not s1.quests.state_parts().is_empty())
