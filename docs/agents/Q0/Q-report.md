# Q0 API (final names; others code against these)
- `sim.quests: QuestLog` (sim/quests/quest_log.gd). Gated by balance `q_enabled` (default false): `QuestLog.is_enabled()`.
- `state(id)->String` idle|active|done; `flag(id)->bool`; `set_flag(id)`; `start(id)`
- `offer(quest_id, beat_id, text, options:[{id,label}])`; `answer(uid, option_id)->bool`; `Simulation.answer_quest(uid, option_id)`
- `schedule(quest_id, beat_id, delay_days)`; `mod(name)->float` (names: audit_parts_mult, wave_mult, refine_mult, fine_pct; 1.0/0.0 default)
- `add_mod(name, value, days)`; `state_parts()->Array` (empty unless a quest started)
- Data: data/quests.json (+ data/quests_q*.json merged by loader): {id:{trigger,beats:{beat:{text,then,options:{opt:{text,effects[]}}}}}}
- Effects: flag, mod, items, mood, debt_pct(<=2%), spawn_colonist, remove_colonist, letter
- Bus: quest_started(id), quest_beat(id,beat,text), quest_choice_posted(uid,id,options), quest_resolved(id,option)
