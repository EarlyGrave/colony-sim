extends TestCase
## F6W2: r4 quest beats and midgame days speak on the Warden PA only.


func _fresh() -> Array:
	var feed := FeedTicker.new()
	var pa := PaBanner.new()
	_owned_nodes.append(feed)
	_owned_nodes.append(pa)
	var sim := make_sim(1, true, 24, 24, peaceful_defs())
	var d := FeedDirector.new(feed, pa)
	d.bind(sim)
	return [sim, feed, pa, d]


func _count(pa: PaBanner) -> int:
	return pa.pending() + (1 if pa.is_active() else 0)


func _beat(q: String, beat: String, want: String) -> void:
	var r := _fresh()
	var sim: Simulation = r[0]
	var feed: FeedTicker = r[1]
	var pa: PaBanner = r[2]
	sim.bus.quest_beat.emit(q, beat, "x")
	assert_eq(_count(pa), 1, q + "." + beat)
	assert_eq(feed.line_count(), 0, "not on feed")
	assert_true(pa.current().begins_with(want), pa.current())
	assert_true(pa.current().length() <= 70, pa.current())


func test_seats() -> void:
	_beat("r4_good_behaviour", "seats", "Seat 7")


func test_gear() -> void:
	_beat("r4_good_behaviour", "gear", "Armour")


func test_bonus() -> void:
	_beat("r4_good_behaviour", "bonus", "A bonus")


func test_wreck() -> void:
	_beat("r4_drone_toll", "wreck", "Drone 12")


func test_pilot() -> void:
	_beat("r4_drone_toll", "pilot", "Pilots")


func test_strike_vote() -> void:
	_beat("r4_drone_toll", "strike_vote", "Smoke")


func test_manifest() -> void:
	_beat("r4_quiet_freight", "manifest", "A crate")


func test_drone_tail() -> void:
	_beat("r4_quiet_freight", "drone_tail", "Suspicion")


func test_unknown_beat_silent() -> void:
	var r := _fresh()
	var pa: PaBanner = r[2]
	r[0].bus.quest_beat.emit("r4_good_behaviour", "recount", "x")
	r[0].bus.quest_beat.emit("other", "b", "x")
	assert_eq(_count(pa), 0)


func test_midgame_days_need_path_flag() -> void:
	var r := _fresh()
	var sim: Simulation = r[0]
	var pa: PaBanner = r[2]
	sim.bus.day_started.emit(40)
	assert_eq(_count(pa), 1, "d40 without flag: only the quiet aside")
	assert_false(pa.current().begins_with("Scars"), pa.current())
	var r2 := _fresh()
	r2[0].quests.set_flag("path_fight")
	r2[0].bus.day_started.emit(40)
	assert_eq(_count(r2[2]), 1, "d40 one line")
	assert_true((r2[2] as PaBanner).current().begins_with("Scars"), (r2[2] as PaBanner).current())
	var r3 := _fresh()
	r3[0].quests.set_flag("path_submit")
	r3[0].bus.day_started.emit(50)
	assert_eq(_count(r3[2]), 1, "d50 one line")
	assert_true((r3[2] as PaBanner).current().begins_with("Mid-term"), (r3[2] as PaBanner).current())


func test_pa_silent() -> void:
	var r := _fresh()
	var sim: Simulation = r[0]
	var pa: PaBanner = r[2]
	sim.quests.set_flag("path_fight")
	sim.quests._mods["pa_silent"] = {"value": 1.0, "until": 999999}
	sim.bus.quest_beat.emit("r4_good_behaviour", "seats", "x")
	sim.bus.day_started.emit(40)
	assert_eq(sim.quests.mod("pa_silent") > 0.0, true)
	assert_eq(_count(pa), 1, "only the quiet aside (not r4)")
	assert_false(pa.current().begins_with("Seat"), pa.current())
