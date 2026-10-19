# Quest batch plan (one wave, 4 parallel workers)
Source: docs/story/quests.md + bible.md (Warden voice: deadpan, passive, <=70 chars/line, English). Owner rule: debt stays
almost unpayable, so no quest option may cut debt by more than a token amount (loophole = one inmate, small, never total).
All workers: `git reset --hard claude/colony-sim-godot-4jftsm` first; shared files only in `# region <agent>`; `sim/` deterministic
(sim.rng only, no Time); tests green; `mktemp -d` only, never broad `pkill`, no background runs left; commit often, never push;
report <=30 lines in docs/agents/<agent>/quest-report.md. Quest code is gated by `balance.json` `q_enabled` (default false).

## Verified code facts (workers must not re-guess)
- Storyteller (`sim/storyteller/storyteller.gd`) has `fire(id)`, `answer(uid, accept)` (binary yes/no only), `pending[]`, `_post`, `_say`, `_apply_effects`, chains in `data/event_chains` (`run_step`, `_schedule`). Choices are 2-way, so 3-way quest choices need QuestLog's own pending kind.
- Hash parts pattern: `MilestoneSystem.state_parts()` appends a row only when state exists (see regions E1/K2). Do the same.
- Audits: `ThreatSystem` K1 clock (`next_audit_tick`, `days_to_audit`), tiers in `MilestoneSystem` (`tier()`, `is_tier_done(t)`, `e3_audit_bonus_days()`), reviews `reviews_done`, `waves_repelled`. Petition: `sim.petition`.
- Dispatch: `ContractSystem.dispatch(tier, modifier_id)`, `wave_mult()`, `take_raid_mult()`. Bus: `story_event`, `letter_received`, `event_choice_posted/resolved`, `wave_started/ended`, `contamination_changed`, `colonist_joined`, `day_started`.
- Eval: `tools/factory_eval.sh --seeds=1-10 --days=60`; goldens `tools/golden*`, `tests/golden/` (regen with `tools/make_golden.gd -- --regen`).

## Q0 QuestLog (owns: sim/quests/*, data/quests.json, tests/test_quests.gd, bus signals, HUD hook, saves)
API (others code against these names): `sim.quests: QuestLog`; `QuestLog.is_enabled()`; `state(id)->String` ("idle|active|done");
`flag(id)->bool` / `set_flag(id)`; `start(id)`; `offer(quest_id, beat_id, text, options:[{id,label}])` posts a pending N-way choice;
`answer(uid, option_id)->bool` (also via `Simulation.answer_quest()`); `schedule(quest_id, beat_id, delay_days)`;
`state_parts()->Array` (empty unless any quest started -> existing hashes/goldens unchanged); `mods`: `audit_parts_mult`, `wave_mult`, `refine_mult`, `fine_pct` each with expiry tick, read-only getters `mod(name)->float`.
Data schema: `data/quests.json` = {id:{trigger:{...conds}, beats:{beat:{text,then,options:{opt:{text,effects[]}}}}}}; effects verbs: `flag`, `mod`, `items`, `mood`, `debt_pct`(clamped to <=2%), `spawn_colonist`, `remove_colonist`, `letter`.
Bus signals (autoload/event_bus.gd, region Q0): `quest_started(id)`, `quest_beat(id, beat, text)`, `quest_choice_posted(uid, id, options)`, `quest_resolved(id, option)`.
Trigger poll once per `day_started`. HUD: minimal quest sheet (list active/done + pending choice buttons >=64 px) in a new `view/quest_sheet.gd`, one line hooked in Hud. Only worker allowed to regen goldens (should be none if gated). Tests: disabled = byte-identical hash; determinism (same seed => same quest log); N-way answer; mod expiry; save round-trip.
Acceptance: Q0 ships a tiny `q_selftest` quest in tests only.

## Q6 Auditor Visits (owns: data/quests_q6.json merged by Q0 loader, tests/test_quest_q6.gd) [S]
Trigger: audit tier 2 passed (`is_tier_done(2)`). Beats: Dispatch announces Auditor Pell -> inspection -> orbital manifest glimpse ("Biomass: forecast").
Choices: Hide pollution (-30 plates, fine avoided, `wave_mult` +20% for 5 d) / Show everything (fine 10% of *current* debt as added interest, sets flag `clue_manifest`) / Dump tour (Auditor shaken: petition fee -5%, +3% pollution).
Lines: "Auditor Pell requests a clean room. We have not been told what that is." / "Pell notes: 'crop yield exceeds expectations.'"
Tests: fires once; each option's mechanical effect; plates insufficient -> option disabled; determinism.

## Q2 Pilgrims of the Slag (owns: data/quests_q2.json, tests/test_quest_q2.gd, small `# region Q2` spawn override in threat_system.gd) [S/M]
Trigger: pollution > 40% first time (`contamination_changed`). Beats: Zealot joins ("Brother Oto"), night prayer at the waste dump, next wave spawns at dump (override `spawn_point`) 30 s late.
Choices: Let him pray (free prep time, Zealot dies 50% via sim.rng) / Silence him (-mood group) / Join (+1 inmate, `refine_mult` 0.85 for 2 d, `wave_mult` 0.8 for 3 d).
Lines: "Brother Oto says the dust is a verdict. Please file your own." / "He is singing to the slag. The slag is listening."
Tests: override applies only to the one wave and then clears; each option; determinism.

## Q1 Clerk's Margin Note (owns: data/quests_q1.json, tests/test_quest_q1.gd, tag in wanderer generation `# region Q1`) [M]
Trigger: first debt payment >=1 refined and a "Clerk" wanderer joined (trait string, data only). Beats: interest clause -> loophole offer -> Warden notices -> payoff.
Choices: Loophole (that inmate's debt -10% only [owner rule], `audit_parts_mult` 1.2 for next audit, Clerk 50% removed) / Report (+10 refined allowance, Clerk mood -, may escape) / Ignore (later clue letter, flag `clue_clause`).
Lines: "Clause 14(c): interest accrues on the debtor. Not the debt." / "A discrepancy has been located. It was not hidden well."
Tests: debt change per option stays within cap, total colony debt never drops >2%; determinism; Clerk removal path.

## Acceptance (orchestrator, after merge + reconcile)
1. Full suite green; with `q_enabled=false` goldens unchanged.
2. Quest probe `tools/quest_probe.gd` (Q0 writes, takes `--seeds --days=60 --quest=<id>`): with `q_enabled=true`, Q6 fires on >=5/10 seeds, Q2 >=6/10, Q1 >=3/10 in 60 d via `tools/factory_eval.sh --ov='{"q_enabled":true}'`; bot audit/P1/P3 pass rates not worse than baseline by >1 seed.
3. Reconcile: if the actual Q0 API differs from the names above, orchestrator (or one fixer) renames; then flip `q_enabled` on, regen goldens once, run `tools/web_smoke.py`.
