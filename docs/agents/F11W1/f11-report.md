# F11W1 report: traits v3 sim wiring (flag `traits_v3_enabled` stays false)
Commits are in the worktree only, nothing pushed. No `STUB F11W2` commit was needed.
- `Simulation`: `traits_v3` + `trait_events` (region F11W1), created only with the flag; `SaveGame.state_hash` adds `traits.state_parts()` only when on.
- `TraitSystem` is a facade when on: `mod()` = `v3.mod + sim.passives.mod` (found lazily via `sim.get("passives")`, 0.0 until W2 lands); `has/def/resolve/grant/acquired_count/has_tag` forward; v2 listeners off. Helpers: `v3_mod` (v3 only), `work_mult`, `research_mult`, `heal_mult`, `severity_mult`, `target_weight_mult`, `thought_sign_mult`, `alarm_ready`, `aura`, `aura_break_mult`, `lean_adjust`, `ids_of`.
- `ColonistGenerator`: `apply_birth` replaces `roll` (before `mark_joined`). `trait_names` lists v3 names.
- `TraitEvents` (new): day_served, calm_day/break, despair day/relief, high/low standing, starving/ate, rescued, downed_in_wave/wave_unscathed, heavy_injury, skill_seven, riot, escape_stopped, scrubbed_cell, exposure_illness (hook in MutationSystem); needs -> `MoodSystem.add_thought`; cellmate/rival bonds (1 `sim.rng` draw per day seeds a child rng); bond break on death/escape; Warden letters from data.
- One-line hooks (`# region F11W1`): melee_damage, injury/illness severity, heal_rate, rest_decay/gain, alarm_delay, target_weight (threat_model colonist_value), mining/scrub speed (work_tick), research_speed, thought_neg/pos, aura_mood, aura_break, block leaning, squad role affinity (`roles.json v3_trait_roles`).
- Data: `traits_v3.json` + `aliases` (integration s4), `letters`, `event_params`; `mood.json` +6 thoughts; `start_opts` maps dossier ids to v3. `TraitSystemV3.event()` got a rule index and a below-threshold fast path (same results).
- Tests: `tests/test_traits_v3_live.gd` (14: 500 newcomers one Charge, consumer stats, Glowtouched via forced illness_chance=1.0, letters/no repeat, Settled at 30 days, needs, bonds, 6-day run). `test_traits_v3.gd` flag-off assert updated. `test_golden` green with the flag off.
- Perf: 250-inmate day roll best-of-10 about 3.5 ms on a box with 3 other test shards running (about 2 ms in quiet runs); test asserts < 4 ms (2 ms target x2 noise margin).
## Deferred (integration.md)
- Stats: suspicion_gain, defiance_gain, contraband_price/find, spot_range, warning_ticks, informant_weight, petition_weight, riot_spread, fixation_chance, debt_total, purify_cost, tend_xp, creature_essence, work_streak/work_switch, standing_effect, aura_xp, faction check for Desertion target_weight.
- Events not emitted: refined_batch (Hums), tainted_kill, mimic_met, block_wiped, reported/informant_gone/made_informant, docked/period_paid, calmed_break.
## Notes for the orchestrator
1. Starting colonists (`ColonistSystem.spawn`) get no traits (as in v2); only generator newcomers do.
2. `legacy.gd` (W2) still saves only `bio.traits`, so v3 ids are not carried to NG+; `start_opts` already accepts them.
3. W4: `colonist_section.gd` reads `bio.traits`; use `sim.traits.ids_of(c)` / `traits_v3.summary(c)`.
4. My new hooks use `v3_mod` (no passives) so W3 can add `+ P` on its own lines without double counting. Expect a merge conflict on job_system.gd:35 (`alarm_ready` appended to the flee condition, W3 edits flee_threshold there).
