# Q0 API (final names; others code against these)
- `sim.quests: QuestLog` (sim/quests/quest_log.gd). Gated by balance `q_enabled` (default false): `QuestLog.is_enabled()`.
- `state(id)->String` idle|active|done; `flag(id)->bool`; `set_flag(id)`; `start(id)`
- `offer(quest_id, beat_id, text, options:[{id,label}])`; `answer(uid, option_id)->bool`; `Simulation.answer_quest(uid, option_id)`
- `schedule(quest_id, beat_id, delay_days)`; `mod(name)->float` (names: audit_parts_mult, wave_mult, refine_mult, fine_pct; 1.0/0.0 default)
- `add_mod(name, value, days)`; `state_parts()->Array` (empty unless a quest started)
- Data: data/quests.json (+ data/quests_q*.json merged by loader): {id:{trigger,beats:{beat:{text,then,options:{opt:{text,effects[]}}}}}}
- Effects: flag, mod, items, mood, debt_pct(<=2%), spawn_colonist, remove_colonist, letter
- Bus: quest_started(id), quest_beat(id,beat,text), quest_choice_posted(uid,id,options), quest_resolved(id,option)

# Status (done)
- Files: sim/quests/quest_log.gd, data/quests.json (+ merges every data/quests_q*.json), view/quest_sheet.gd (hook: `# region Q0` in hud.gd), tests/test_quests.gd (5), tools/quest_probe.gd, mood thoughts quest_uneasy/quest_cheer, docs/sim_contract.md rows.
- Relay additions: trigger `tier_done`; option `requires.item/n` or `requires.items` ({id:n} or [{item,n}]); mods have `petition_fee_mult`; mod days<=0 = permanent; effects `pollution{value}` (fraction of max, 0.03=+3%), `debt_pct` (reductions clamped to 2% of colony debt, positive = fine), `letter{text}`.
- Code drivers: `register_module(quest_id, obj)` (obj.poll() each day_started, obj.resolve(option_id) for its offers, obj.state_parts() appended to hash). `register_cond(name, Callable)` for custom triggers.
- set_mod(name, value, DAYS); set_mod_until(name, value, expiry_TICK) -> Q1 must use set_mod_until (or days).
- Wired: only `wave_mult` (ThreatSystem._o3_mult, region Q0). NOT wired (orchestrator reconcile): refine_mult, audit_parts_mult, fine_pct, petition_fee_mult, Q2 q2_arm.
- Saves: replay-based; answer_quest is a recorded command. Suite: all green after contract-doc fix (785+2 fixed). Goldens untouched (flag off).
