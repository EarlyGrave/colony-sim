# F5 plan: Mid-game dials + mid-game stories (prompter, 2026-10-20)
Sources: docs/scout/midgame_loop.md (#1,#2,#4), docs/story/round4_midgame.md. One wave, 4 workers, disjoint files, <=4 cores (factory_eval --jobs=1).
Not in F5 (backlog): Scrubber (#3, needs pillar-table gate), creature haze, Slag Heap. Main bar: full suite green + web_smoke + bot alive>=8 >= 6/10.
Common rules: reset to claude/colony-sim-godot-4jftsm; import; quick tests only; report in reply; `.uid` files committed; flags in data/balance.json.
Bot table per worker (60 d, seeds 1-10, `tools/factory_eval.sh --jobs=1 --ov=...`): feature OFF vs ON | alive>=8 | audit | P1 | P3. ON must keep alive>=8 >= 6/10.
Shared files (all edits ONLY inside `# region <W>`): sim/core/simulation.gd (var + init + tick hook + command), docs/sim_contract.md (HARD <=250 lines, now 250:
a row per recorded command AND per new data file; join prose lines to stay net zero), view/panels/panel_registry.gd (one line under a free slot), tools/factory_bot.gd
(one knob per worker via `pg_bot`), sim/core/defs.gd (W1/W3/W4 file loading). New saved state goes into the owner's own to_dict/from_dict. Merge order: W4 -> W2 -> W3 -> W1; full suite once after W1.

## W1 Standing Orders (scout #1)  [flag `reg_enabled` OFF by default]
Own: NEW data/regulations.json, NEW sim/regulations/regulation_system.gd, NEW view/panels/regulation_card.gd, tests/test_f5_regulations.gd.
Shared: simulation.gd region W1 (var, init, tick, command `choose_regulation(slot:int, id:String)`, _record first line); contract rows (command + data file); registry line "orders"; defs.gd region W1 (load json);
contamination_system.gd line 37 region W1 (waste mult read from `sim.regulations.mult("waste")`); factory_bot region W1.
Design: slots at day 15/30/45 (data); each slot offers 3 mutually exclusive options with `cost` text + `effects` dict. Effects only via existing hooks: quests.set_mod permanent
(`refine_mult`, `wave_mult`, `despair_mult`, `petition_fee_mult`, `audit_parts_mult`), debt installment %, mood thought, turret fire-rate/slot via new data key read in ONE place each. Earlier pick locks branches (`excludes`).
Pending slot with no answer auto-picks `default` after 2 days (like CrisisSystem timeout). UI: modal card like crises/event_choice, 3 buttons >= 64 px, fits 844x390, shows one price line each.
Accept: save/load round-trip; same seed+commands = same hash; excluded option rejected; timeout default; flag OFF = goldens unchanged; text English <=70 chars/line; bot knob `pg_bot.reg_pick` (0=none, 1..3 = option index) + eval column `regs`.
Table: each option vs none; ship ON only if no option drops alive>=8 below 6/10 (else keep flag OFF and report).

## W2 Petition Waivers (scout #2)  [alt payments ON, optional; bot uses them only with knob `pg_bot.use_alt`]
Own: sim/research/petition_system.gd (region W2), data/petitions.json (`alt` block per phase), NEW sim/jobs/detail_job.gd (+ registration in the JobSystem work-giver list, region W2),
view/panels/petition_panel.gd, tests/test_f5_waivers.gd.
Shared: simulation.gd region W2 (command `deliver_petition_alt(phase:int, alt_id:String)`, _record first line; contract row); factory_bot region W2.
Design: P1 alt "Volunteer Detail": 3 volunteers (not downed/not Informant) do N work-hours of hazardous haul at a nest edge or blocked drill; completion = phase paid as if plates delivered; injury chance through existing health;
P3 alt "Informant Report": needs informant_alive; suspicion +X (contraband), Informant block Standing -Y via blocks._change; no item cost. One alt per phase, items already delivered are kept/credited proportionally.
Accept: alt unavailable when preconditions fail (no volunteers / no informant / contraband off => alt hidden, not crash); rejected command changes no state; reward identical to normal completion (petition_phase_done emitted once);
volunteer death does not soft-lock the phase (job fails, phase stays open); panel shows the 2nd row at phone size; save/load mid-detail.
Bot: seeds that stall on P1 (plates<60 at d25): P1/P3 counts with `use_alt` ON vs OFF; target P3 >= baseline+1, alive>=8 not lower than 6/10.

## W3 Fixation (scout #4)  [flag `fixation_enabled` OFF until bot numbers; decline is free]
Own: NEW data/fixation.json, NEW sim/fixation/fixation_system.gd, tests/test_f5_fixation.gd.
Shared: simulation.gd region W3 (var, init, tick hook; no new command: accept/decline reuses the Storyteller pending-choice `answer(uid, accept)` + event_choice panel, so NO contract command row; one data-file row);
data/mood.json (+1 thought `fixation`, +1 break kind if needed, region comment key), data/flavor.json (pa lines, region W3 keys prefix `fix_`); factory_bot region W3 (`pg_bot.fixation_accept`, default 0 = decline).
Design: once per game from day ~25 pick a colonist with crafting/engineering level >= 3 (trait-weighted, sim.rng only); offer "Fixation": 6 plates + 2 refined_essence reserved from stock within 3 days.
Accept -> inmate works a bench; success = ONE named masterwork GearItem (sim.give_gear, top rarity, name signed "<Name>'s <base>", stored in bio/epilogue hook for the Q15/epilogue tie); fail (items missing at deadline) = mood break (existing break_job) and reserved items lost.
Decline = nothing. Accept: deterministic; items never double-spent against petition (reservation visible in count); death/downed of the inmate cancels and refunds; save/load mid-fixation; goldens unchanged with flag OFF.
Table: accept-always vs decline: alive>=8, P4 refined at d60, gear equipped count.

## W4 Quest verbs + r4 story lines  [ON; story is data, new verbs optional by fallback]
Own: sim/quests/quest_log.gd (region W4: verbs `trait{who,id}`, `credit{n}`, `suspicion{n}`, `defiance{n}`; `{dead}` text placeholder filled from last dead colonist / Enemy.name_of_dead, static fallback when none),
sim/society/society_conds.gd (region W4: conds `raids_survived N`, `defiance_over N`, `gear_owned N`), NEW data/quests_s6.json (the 3 quests r4_good_behaviour, r4_drone_toll, r4_quiet_freight; ids keep r4_),
data/flavor.json pa lines (region W4 keys `r4_*`), tests/test_f5_r4_quests.gd.
Shared: defs.gd region W4: NOTE the loader globs only `quests_q*`/`quests_s*` and the web-export fallback list at defs.gd:124 must get `quests_s6.json` too (else quests vanish in the web build). No simulation.gd command; no contract command row; add data-file row.
Find real field names first: escape credit (shuttle/fight_escape), contraband.suspicion, metro defiance (sim/threats/metro_track.gd), metro raids repelled counter, TraitSystem acquired-trait API. If a counter does not exist, add it in the owner's system inside region W4 (one int, saved).
Design: story doc beats A1-A4, B1-B4, C1-C4 verbatim in structure; every [NEW] beat keeps its [DATA] fallback only if the verb is missing at load (log a warning, never crash); mod names must be ones consumed today (wave_mult, refine_mult, audit_parts_mult, despair_mult); verify the "refining 0 for 2 d" mod = `refine_mult` 0.0.
Accept: each quest reaches done on forced flags (pattern: tests/test_story_paths.gd); each option applies its effects once; text <=70 chars/line; {dead} resolves with and without a death; goldens unchanged; quests never start before their min_day or without the path flag.
Bot: 60 d on path_submit/fight/escape seeds, alive>=8 not lower than 6/10 (quests add real costs: pollution, wave_mult 1.1).

## Orchestrator after merge
Regenerate goldens only if a diff appears; full sharded suite; web_smoke; one bot table with all flags ON/OFF; PROGRESS/DECISIONS rows; rollback_points.md row on merge to main.
