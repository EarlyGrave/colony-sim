# F6 plan: Story engine polish (prompter, 2026-10-20)
Sources: PROGRESS F5 notes, docs/story/round4_midgame.md, next_batches A8, real code (quest_log.gd, society_conds.gd, quests_s6.json, feed_director.gd, ending_system.gd, win_screen.gd).
One wave, 3 workers (W4 dropped, see end), no balance tuning, no owner decisions. Common: reset to claude/colony-sim-godot-4jftsm; `--import`; quick tests only; `.uid` committed; report in reply.
Rules: sim deterministic (no new rng); goldens must NOT change (`tools/make_golden.gd` diff empty); all text English <=70 chars/line; shared files edited only inside `# region <W>`.
sim_contract.md stays <=250 lines (now 250): no new recorded command is planned, so no row; if a worker needs a line, join prose lines to stay net zero.
Merge order: W1 -> W3 -> W2 (W1 and W3 both touch quest_log.gd and quests_s6.json: separate hunks, take both on conflict). Full suite once after the last merge, then web_smoke.

## W1 Beat gating  (region F6a)
Own: sim/quests/quest_log.gd region F6a (schedule/_on_tick only), data/quests_s6.json (`wait` keys on r4 beats), tests/test_f6_gating.gd.
Design: a beat may carry `"wait": {cond dict}` (AND) or `"wait": [dict, dict]` (OR), plus `"wait_max_days": N` (default 10). Cond dict uses the same keys as quest triggers, evaluated by existing `_trigger_ok()`.
`schedule()` stores `limit = due + wait_max_days*ticks_per_day` on the entry only when the target beat has `wait`. In `_on_tick`, when an entry is due and its wait is false and tick < limit: re-insert with due = next day boundary (daily re-check, same sorted insert). At limit the beat is entered anyway (no stuck quests).
State: `state_parts()` appends `limit` ONLY for entries that have one, so dumps and saves without waits are byte-identical; save/load restores limit.
Switch r4 delays to the story doc triggers (keep the `delay_days` as the minimum): A3 gear `min_day 40` (wait on gear beat); B1 stays on the trigger; B3 strike_vote `[block_standing_below any 20, min_day 45]`; B4 scars `raids_survived 3`; C2 inspection `suspicion_over 40`; C4 drone_tail `suspicion_over 60`. Missing system (contraband off) falls to the max wait.
Accept: beat waits then fires the day the cond turns true; fires at max wait if never true; OR list works; same seed+commands = same hash; save/load mid-wait resumes with the same limit; the three r4 lines still finish in test_f5_r4_quests (forced flags may need `wait_max_days` or cond setup: update that test minimally).
Tests: tests/test_f6_gating.gd (wait/limit/OR/save-load/determinism) + the existing r4 and story_paths tests green.

## W2 Feed and PA  (view only)
Own: view/feed_director.gd, view/flavor_picker.gd (consts only), data/flavor.json `pa` block only, tests/test_feed.gd, NEW tests/test_f6_feed.gd.
Finding: r4 PA lines sit in flavor.json `pa.r4_*` per quest, no code reads them. Fixation `fix_*` already reach the player as "Warden" letters from the sim; regulations have NO PA lines and no bus signal (flag OFF): leave both alone, do not double-show.
Design: FeedDirector connects `bus.quest_beat`; key order `pa.<quest>.<beat>` then `pa.<quest>`; one PA line per beat entry via the existing picker (cosmetic, no sim.rng). Re-key the 8 quest lines in flavor.json per beat (seats: "Seat 7 is reserved...", gear: "Armour is a form of ambition...", wreck: "Drone 12 failed...", pilot: "Pilots are replaceable...", wreck-burned/strike_vote: "Smoke on the horizon...", manifest: "A crate is not a sale...", drone_tail: "Suspicion is at 60..."; bonus: "A bonus is a loan..."). `r4_midgame` lines: PA on day_started 40 ("Scars...") and 50 ("Mid-term review...") only when a path flag is set. Respect `sim.quests.mod("pa_silent") > 0` (no PA). Update the class header comment with the new surface.
Accept: each r4 beat entry announces exactly one line, <=70 chars, on PA not feed; pa_silent suppresses; missing key = no line (no "..." filler for these); no change to the existing signals' behaviour.
Tests: one test per hook (8 beat hooks + d40 + d50 + pa_silent), driving bus.quest_beat.emit on a bound FeedDirector.

## W3 Story fidelity  (region F6c)
Own: sim/quests/quest_log.gd region F6c (new verb + helper), data/quests_s6.json (pilot `recruit` option + nothing else), data/flavor.json `epilogue_echo` block (new, separate from `pa`), sim/endings/ending_system.gd region F6c, view/panels/win_screen.gd region F6c, tests/test_f6_fidelity.gd.
1) Pilot name: verb `rename {who:"pilot", to:"dead"}` after `spawn_colonist as pilot`: sets display_name to the dead inmate name chosen like `{dead}` (reuse the `_w4_text` rule via one shared helper `dead_name()`; prefer an inmate dead >10 d, else last dead, else keep the generated name). Only on the Recruit option; one more dispatch arm in the `_apply_effects` match.
2) Epilogue echo: `EndingSystem.epilogue_for(id, sim)` = base lines + `epilogue_echo.<id>` entries `{flag, line}` whose quest flag is set (submit: r4_seat_kept -> "Seat 7 stayed empty. Someone kept the door."; add one echo per other path from the existing r4 flags, e.g. r4_pilot, r4_sold_name) + masterwork line when `sim.fixation.masterworks` is non-empty (up to 2 names, e.g. "Hung on the wall: <name>, <name>."). `mark_won` letter and win screen both use it (find where win-screen stats are built and pass the echo lines in stats["epilogue_echo"]; `epilogue_lines(id)` keeps its static signature).
Accept: Recruit renames to a dead name when one exists; epilogue unchanged when no flags/masterworks (existing 4 win-screen cases still pass); each echo appears only with its flag; masterwork names shown; text <=70 chars/line; goldens unchanged.
Tests: tests/test_f6_fidelity.gd (rename with/without dead, echo on/off per flag, masterwork line, win screen at 844x390 still shows buttons).

## W4 Per-area pollution marker: NOT in this wave
Reason: F4d already treats the waste_dump zone (else processors) as the pollution peak (`f4d_pollution_peak`, flag `spawn_at_pollution_peak` OFF), so a second hot-spot would duplicate it. A real per-area value would change ContaminationSystem state/dump and the goldens, which this batch forbids. A map tint of the dump zone is view-only and can be a later one-worker task on view/world_view.gd once the owner decides whether the flag goes ON.
