# Q2 Pilgrims of the Slag - report
Done: data/quests_q2.json, sim/quests/q2_pilgrims.gd (class Q2Pilgrims), tests/test_quest_q2.gd (7 tests),
`# region Q2` in sim/threats/threat_system.gd (q2_arm + one-shot origin override, held in object Q2Spawn so golden dump unchanged),
mood thought `silenced_prayer` in data/mood.json, row in docs/sim_contract.md. Full shards: all green (after doc row).
Flow: poll() daily (pollution fraction >= 0.40, q_enabled) -> begin(): Brother Oto joins, letter, offer 3 options ->
resolve(let|silence|join). Let: next wave +30 s and spawns at waste_compactor (else map center), Oto dies 50% (sim.rng, rolled at
choice, applied on wave_ended). Silence: -6 mood 2 d all. Join: +1 inmate, refine_mult 0.85 2 d, wave_mult 0.8 3 d. No debt effect.
Assumed QuestLog names (guarded via sim.get("quests"), absent in tests): offer(quest_id, beat_id, text, options), set_flag(id),
set_mod(name, mult, days). Orchestrator must wire: construct Q2Pilgrims in QuestLog/Simulation, call poll() on day_started,
route answer(uid, option_id) to resolve(), append state_parts() to hash parts, and make mods feed wave_mult/refine_mult
(last_mods mirrors them). Q2Pilgrims also reads balance["q_enabled"] itself.
Pillar: gated off, one-time, wave_mult 0.8 only for 3 d on Join; tools/kx_pillar_table.gd not re-run (no change when disabled).
