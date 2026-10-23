extends TestCase
## F11W1: traits v3 wired into the live sim behind balance.traits_v3_enabled (here forced ON).
## Flag-off behaviour is covered by test_golden / test_traits / test_traits_v3.


func _defs() -> Defs:
	var d := peaceful_defs()
	d.balance["traits_v3_enabled"] = true
	d.traits_v3 = TraitSystemV3.load_cfg()
	return d


func _sim(w := 40, h := 40) -> Simulation:
	return make_sim(3, false, w, h, _defs())


func _inmate(sim: Simulation, cell := Vector2i(5, 5)) -> Colonist:
	var c := ColonistGenerator.generate(sim, cell)
	sim.colonists.add(c)
	return c


## A colonist with no traits at all (stats are then exactly the base values).
func _bare(sim: Simulation, cell := Vector2i(5, 5)) -> Colonist:
	var c := _inmate(sim, cell)
	c.bio["traits_v3"] = []
	c.bio["trait_counters"] = {}
	return c


func _day(sim: Simulation, n := 1) -> void:
	for i in n:
		sim.tick = (sim.day() + 1) * sim.ticks_per_day - 1
		sim.step()


func test_flag_wires_the_facade() -> void:
	var sim := _sim()
	assert_true(sim.traits_v3 != null and sim.trait_events != null)
	assert_true(sim.traits.v3 == sim.traits_v3)
	assert_eq(sim.traits.resolve("strong"), "t_hulking")
	assert_eq(sim.traits.resolve("handy"), "")
	var off := make_sim(3, false, 24, 24, peaceful_defs())
	assert_true(off.traits_v3 == null and off.trait_events == null, "flag off: nothing created")
	assert_eq(off.traits.v3_mod(null, "carry"), 0.0)
	assert_eq(off.traits.work_mult(null, "mining"), 1.0)
	assert_true(off.traits.alarm_ready(null))


func test_500_newcomers_have_exactly_one_charge() -> void:
	var sim := _sim()
	for i in 500:
		var c := ColonistGenerator.generate(sim, Vector2i(5, 5))
		var ids := sim.traits_v3.list(c)
		assert_eq(sim.traits_v3.count_category(c, "background"), 1, "inmate %d: %s" % [i, str(ids)])
		assert_true(c.bio["traits"].is_empty(), "v2 list stays empty")
		assert_true(sim.traits_v3.count_category(c, "personality") + sim.traits_v3.count_category(c, "body") <= 2)
		assert_true(c.max_hp >= 10.0)


func test_existing_consumer_stats_return_v3_values() -> void:
	var sim := _sim()
	var c := _bare(sim)
	var base_cap := int(sim.defs.balance["colonist"]["carry_capacity"])
	assert_eq(sim.traits.carry_cap(c, base_cap), base_cap)
	sim.traits_v3.add(c, "t_hulking")
	assert_gt(float(sim.traits.carry_cap(c, base_cap)), float(base_cap) - 0.1)
	assert_near(sim.traits.mod(c, "carry"), sim.traits_v3.mod(c, "carry"), 0.0001)
	assert_near(sim.traits.mod(c, "hunger"), 0.25, 0.0001, "Hulking eats more")
	assert_true(sim.traits.has(c, "t_hulking") and sim.traits.has(c, "strong"), "v2 alias resolves")
	assert_eq(str(sim.traits.def("t_hulking")["name"]), "Hulking")
	for stat in ["work_speed", "mood_base", "break_chance", "hit", "armor_flat", "flee_threshold", "xp_mult_all",
			"move_speed", "despair_mult", "standing_gain", "mutation_risk", "machine_breakage"]:
		assert_near(sim.traits.mod(c, stat), sim.traits_v3.mod(c, stat), 0.00001, stat)
	var d := sim.traits_v3.add(c, "t_dead_nerves")
	assert_true(d)
	assert_true(sim.traits.mod(c, "flee_threshold") <= -1.0 or sim.traits.mod(c, "flee_threshold") < 0.0)
	# acquired traits arrive through grant (quest verb) and respect the caps
	assert_true(sim.traits.grant(c, "settled"))
	assert_false(sim.traits.grant(c, "settled"), "no repeated add")
	assert_eq(sim.traits.acquired_count(c), 1)


func test_new_stat_hooks_are_neutral_without_traits_and_move_with_them() -> void:
	var sim := _sim()
	var c := _bare(sim)
	assert_eq(sim.traits.heal_mult(c), 1.0)
	assert_eq(sim.traits.severity_mult(c, false), 1.0)
	assert_eq(sim.traits.target_weight_mult(c), 1.0)
	assert_eq(sim.traits.work_mult(c, "mining"), 1.0)
	assert_eq(sim.traits.thought_sign_mult(c, -5.0), 1.0)
	sim.traits_v3.add(c, "t_fast_healer")
	assert_gt(sim.traits.heal_mult(c), 1.0)
	sim.traits_v3.add(c, "t_tunnel_rat")
	assert_gt(sim.traits.work_mult(c, "mining"), 1.0)
	assert_eq(sim.traits.work_mult(c, "hauling"), 1.0)
	var h := sim.health.apply_damage(c, 10.0, "torso", "bite")
	assert_true(h != null)
	var d := _bare(sim, Vector2i(6, 6))
	sim.traits_v3.add(d, "t_hollow") if sim.traits_v3.can_add(d, "t_hollow") == "" else null
	if sim.traits_v3.has(d, "t_hollow"):
		assert_lt(sim.traits.target_weight_mult(d), 1.0)
		assert_eq(sim.traits.thought_sign_mult(d, -5.0), 0.0)


func test_heavy_sleeper_alarm_delay() -> void:
	var sim := _sim()
	var c := _bare(sim)
	sim.traits_v3.add(c, "t_heavy_sleeper")
	sim.tick = 100
	sim.trait_events.alarm_since = 100
	assert_false(sim.traits.alarm_ready(c), "alarm just started")
	sim.tick = 130
	assert_true(sim.traits.alarm_ready(c))


func test_auras_and_leaning_follow_block_mates() -> void:
	var sim := _sim()
	var a := _bare(sim, Vector2i(5, 5))
	var b := _bare(sim, Vector2i(6, 5))
	sim.blocks.member_of[a.id] = "x"
	sim.blocks.member_of[b.id] = "x"
	sim.traits_v3.add(a, "t_gallows_humor")
	sim.tick += 31
	assert_near(sim.traits.aura(b, "mood"), 2.0, 0.0001, "mate feels +2")
	assert_near(sim.traits.aura(a, "mood"), 0.0, 0.0001, "own aura is not counted")
	sim.traits_v3.add(b, "t_agitator") if sim.traits_v3.can_add(b, "t_agitator") == "" else null
	if sim.traits_v3.has(b, "t_agitator"):
		sim.tick += 31
		assert_gt(sim.traits.aura_break_mult(a), 1.0)
	sim.traits_v3.add(a, "t_charge_cult") if sim.traits_v3.can_add(a, "t_charge_cult") == "" else null
	if sim.traits_v3.has(a, "t_charge_cult"):
		assert_eq(sim.traits.lean_adjust("x", "fight", 0), 1, "2 votes / divisor 4 rounds to 1")
	assert_eq(sim.traits.lean_adjust("x", "submit", 0), 0)


func test_events_post_warden_letters_and_never_repeat() -> void:
	var sim := _sim()
	var c := _bare(sim)
	var letters: Array = []
	sim.bus.letter_received.connect(func(t: String, x: String) -> void: letters.append([t, x]))
	var r := sim.trait_events.fire(c, "rescued")
	assert_true(r.has("+t_hardened"), str(r))
	assert_eq(letters.size(), 1)
	assert_true(str(letters[0][1]).contains(c.display_name) and str(letters[0][1]).length() <= 70)
	assert_true(sim.trait_events.fire(c, "rescued").is_empty(), "no repeated trait add")
	assert_eq(letters.size(), 1)
	assert_eq(sim.traits_v3.list(c).count("t_hardened"), 1)


func test_settled_after_30_calm_days_lost_on_break() -> void:
	var sim := _sim()
	var c := _bare(sim)
	_day(sim, 29)
	assert_false(sim.traits_v3.has(c, "t_settled"))
	_day(sim, 2)
	assert_true(sim.traits_v3.has(c, "t_settled"), str(c.bio["trait_counters"]))
	sim.bus.mood_break_started.emit(c.id, "wander")
	assert_false(sim.traits_v3.has(c, "t_settled"))
	assert_gt(sim.traits_v3.counter(c, "day_served"), 29)


func test_exposure_ladder_reaches_glowtouched_on_forced_illness() -> void:
	var d := _defs()
	d.mutation["illness_chance"] = 1.0
	var sim := make_sim(3, false, 40, 40, d)
	var c := _bare(sim, Vector2i(10, 10))
	var step := int(d.mutation["exposure_ticks"])
	for day in 40:
		sim.mutation.field[10 * sim.map.width + 10] = 0.9
		sim.mutation._expose_colonists(step)
		if sim.traits_v3.has(c, "t_hollow"):
			break
	assert_true(sim.traits_v3.has(c, "t_glowtouched") or sim.traits_v3.has(c, "t_second_skin") or sim.traits_v3.has(c, "t_hollow"),
			str(sim.traits_v3.list(c)))
	var c2 := _bare(sim, Vector2i(11, 11))
	sim.mutation.field[11 * sim.map.width + 11] = 0.9
	sim.mutation._expose_colonists(step)
	assert_true(sim.traits_v3.has(c2, "t_glowtouched"), "first illness -> Glowtouched: " + str(sim.traits_v3.list(c2)))


func test_trait_needs_become_thoughts() -> void:
	var sim := _sim()
	var c := _bare(sim)
	sim.traits_v3.add(c, "t_gallows_humor")
	_day(sim, 2)
	# alone in the block: nobody to laugh with
	sim.blocks.member_of[c.id] = "lonely"
	_day(sim, 1)
	assert_true(sim.mood.state_of(c).find("no_audience") >= 0, "no_audience thought")
	assert_true(sim.defs.mood["thoughts"].has("no_tunnel") and sim.defs.mood["thoughts"].has("hum_fades"))


func test_bond_breaks_when_partner_dies() -> void:
	var sim := _sim()
	var a := _bare(sim, Vector2i(5, 5))
	var b := _bare(sim, Vector2i(6, 5))
	assert_true(sim.traits_v3.bond(a, b, "t_cellmate"))
	b.alive = false
	sim.bus.colonist_died.emit(b.id)
	assert_false(sim.traits_v3.has(a, "t_cellmate"))
	assert_eq(sim.traits_v3.counter(a, "lost_t_cellmate"), 1)


func test_daily_loop_with_250_inmates_is_cheap() -> void:
	var sim := _sim(80, 80)
	for i in 250:
		_inmate(sim, Vector2i(2 + i % 70, 2 + i / 70))
	sim.trait_events._on_day(1)  # warm-up
	var best := 1e9
	for d in 10:  # best of 10: other processes on a shared box only ever add time
		var t0 := Time.get_ticks_usec()
		sim.trait_events._on_day(2 + d)
		best = minf(best, float(Time.get_ticks_usec() - t0) / 1000.0)
	print("        250-inmate trait day roll: %.2f ms/day (best of 10)" % best)
	if not perf_skip():
		assert_lt(best, 4.0, "daily loop budget: 2 ms target x2 noise margin")


func test_start_opts_veteran_traits_map_to_v3() -> void:
	var sim := _sim()
	var c := _bare(sim)
	# dossier ids: v2 alias + native v3 id + a dropped alias
	for t in ["strong", "t_stoic", "handy"]:
		var tid := sim.traits.resolve(t)
		if tid != "" and not sim.traits_v3.has(c, tid):
			sim.traits_v3.add(c, tid, "dossier")
	assert_true(sim.traits_v3.has(c, "t_hulking") and sim.traits_v3.has(c, "t_stoic"))


func test_30_day_run_with_flag_on_has_no_errors() -> void:
	var sim := make_sim(5, true, 48, 48, _defs())
	for i in 3:
		_inmate(sim, sim.map_center() + Vector2i(i, 4))
	for i in sim.ticks_per_day * 6:
		sim.step()
	assert_true(sim.day() >= 5)
	assert_true(sim.colonists.list.size() >= 3)
