# Batch R plan: story quests, shuttle bot, UI nit (one wave, 5 workers)
Base: `git reset --hard claude/colony-sim-godot-4jftsm`. Tests during work: tools/run_tests_quick.sh; full tools/run_tests_sharded.sh once at the end.
Common rules: never `pkill` broadly (kill only own PIDs); leave no background runs; use `mktemp -d` for temp output; commit often in the worktree, never push; report <=30 lines in docs/agents/R<n>/R-report.md; shared files only inside `# region R<n>`; sim/ deterministic (sim.rng only); all in-game text English; goldens must stay byte-identical except R4.
Quest data schema: copy data/quests_q6.json (keys: id, title, trigger, start, beats with text/options{id,label,hint,requires,effects}, `n`/`pct` keys). Effects available: items, mod, flag, letter, debt_pct, pollution (QuestLog._apply_effects). Triggers in QuestLog._trigger_ok: min_day, flag, not_flag, quest_done, tier_done, pollution_over, reviews_done; custom via register_cond(name, Callable).
Spec source: docs/story/quests.md ("Next build" list, Q-sections) - use its lines verbatim.

## R1 Q10 Maintenance Window + Q3 Parole Board (data only)
Own: data/quests_q10.json, data/quests_q3.json, tests/test_r1_quests.gd.
- Q10: trigger min_day 40 + flag installment_missed (set it from DebtSystem on first unpaid installment after grace; the hook is the ONLY sim edit, in `# region R1`, no rng). PA silent 6 h then "Apology form 9-A". Options raid / respect / sabotage as in "Next build" 1; sabotage must really block audits+letters for 3 d via a mod.
- Q3: trigger reviews_done 1; Sponsor / Decline / Bribe Informant; hint shows cost vs the 4/inmate installment rate.
- Accept: each option applies its effects (test per option), replay-hash test with an answered quest equals across 2 runs, goldens identical, the quest sheet renders both (tests/test_quest_sheet.gd still green).

## R2 Q8 What the Creatures Wear (+ mimic enemy def)
Own: data/quests_q8.json, mimic entry in data/enemies.json (+ sprite alias, no new art), tests/test_r2_q8.gd.
- Trigger pollution_over 70 + quest_done q2. Options Feed (wave_mult 0.5 2 d, pollution +10) / Cleanse (40 plate, pollution -15) / Study (flag clue_survey_tag, essence drop 2 d). Mimic: reuse an existing enemy archetype stats scaled from data, spawned only by the quest, never by normal waves.
- Pillar guard: `godot --headless --path . -s tools/kx_pillar_table.gd -- --days=21 --seeds=5` standard_term throttle must stay >=2 waves below baseline (currently 6.2 vs 4.0) with the quest enabled; paste the table in the report.
- Accept: option effects tested, mimic def loads via Defs and a spawn test passes, goldens identical.

## R3 sentence_min trigger + Q11 Previous Tenant + Q12 Rolled Over (NG+)
Own: data/quests_q11.json, data/quests_q12.json, tests/test_r3_ng_quests.gd.
- Add `sentence_min` (and `carry_debt` > 0 cond) in QuestLog._trigger_ok inside `# region R3`; read sentence from the MetaState the sim was built with (check real field name in meta state / test_ng_meta.gd).
- Q11: sentence_min 2 + min_day 6 (open / bury / report). Q12: sentence_min 3 + quest_done q11 + carry_debt (pay / contest via sim.rng 50% / accept, flag clue_quota).
- Tests with MetaState NG opts: sentence 1 -> neither fires; sentence 2 -> only Q11; sentence 3 + carried debt -> Q12 after Q11; contest outcome deterministic per seed.
- Accept: sentence-1 runs byte-identical (goldens untouched), suite green.

## R4 Shuttle launch by the real bot + haul_blocked_fix balance (sole golden regenerator)
Own: tools/factory_bot.gd, tools/factory_bot_report.gd, data/balance.json, tests/golden/*, tests/test_r4_*.gd.
- Bot: gantry (release_gantry via _shuttle), fuel cells from nitrogen (_nitrogen_trickle / --nitrogen), parts supply, siege defense (turret reserve) until `sim.launch_shuttle()`; bot.blocker() must name the missing piece in the report.
- Balance: turn `haul_blocked_fix` true and tune (pacing/bot) so factory_eval alive>=8 stays >=7/10.
- Accept: `tools/factory_eval.sh --seeds=1-10 --days=60`: launch >=1/10, alive>=8 >=7/10, audit tier 2 >=6/10; pillar table still >=2 gap; regenerate goldens once with tools/make_golden.gd -- --regen and list changed ticks in the report; web_smoke PASS.

## R5 UI nit: quest sheet vs notification stack
Own: view/quest_sheet.gd, view/hud.gd only in `# region R5`, tests/test_r5_ui.gd, docs/agents/R5/*.png.
- At 844x390 (DPR3, --w=2532 --h=1170 --scale=2.55) the open quest sheet must not overlap the toast/notification stack (rect-intersection test on both Controls with a toast and a pending quest; move/shift the stack or cap sheet height).
- Accept: test passes, screenshot `--panel=quest` committed, world-visible >=55% test unaffected, web_smoke PASS.
