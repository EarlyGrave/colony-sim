# Pacing batch plan (K1-K5) — one wave, 5 parallel workers
Source: docs/scout/pacing.md, PROGRESS "Design batch B / Open", DECISIONS tail. All workers: `git reset --hard claude/colony-sim-godot-4jftsm`
first; shared files only inside `# region K<n>` blocks; sim deterministic (sim.rng, tick counts); commit in worktree, never push;
report <=30 lines in docs/agents/K<n>/pacing-report.md. Run the full suite (tools/run_tests_sharded.sh 4) before finishing. Never pkill broadly (kill only your own PID).
Golden policy: ONLY K1 regenerates goldens (`tools/make_golden.gd -- --regen`). K2/K3/K4/K5 gate behaviour behind `balance.json`
flags `k2_enabled`, `k5_enabled` (default false; K4 is behaviour-preserving, no flag; K3 is view-only). Orchestrator flips flags after merge.

## K1 — calm-after-hit + sentence-audit floor clock (owner: sim/threats/*, sim/storyteller/*, data/presets.json, data/threat.json, data/balance.json `pacing` key, tools/b1_preset_table.gd, tests/test_k1_pacing.gd)
- Presets get `calm_after_hit_days` (short 2x / standard 1x / hard 0.4x of base) and `audit_interval_days` (6/4/3).
- Calm: after a wave kills a colonist or breaks a link, no pollution wave spawns for the calm window.
- Sentence clock: every audit interval spawn a small "audit patrol" (floor_pts_per_day * interval, preset-scaled) independent of pollution;
  a clean colony still meets it. Expose `sim.threats.next_audit_tick()` and `days_to_audit()` (K3 reads these).
- Accept (bot table, 5 seeds, extend tools/b1_preset_table.gd): mean waves by d21 ~ 4 / 6 / 8 (short/standard/hard, +-1);
  clean-colony hard gets >=1 audit by d10; seed 3 planet_dead d21 not worse on standard; deaths short < standard < hard.
- Tests: audit fires on schedule per preset; calm suppresses pollution wave; determinism (same seed twice); goldens regenerated, changed ticks listed in report.

## K2 — preset-scaled Parole Review + outposts (owner: sim/research/milestone_system.gd review section, data/milestones.json, sim/campaign/expedition.gd + sim/campaign/campaign.gd (outpost parts), view/panels/reviews_panel.gd, tests/test_k2_reviews.gd)
- Review demands scale per preset: debt% and waves-repelled (short -1 wave, standard base 2, hard +1 and debt +2 pts).
- New review step "outpost held N days" (standard/hard; free on short). Outposts count as audit decoys: while an outpost is held,
  the next audit patrol hits it first (skip home audit once, uses K1 `next_audit_tick` hook via a `# region K2` call; if K1 absent, no-op).
  Essence stockpiled at an outpost is exempt from hoard/essence clock (flag only; clock itself stays off).
- Behind `k2_enabled`. Accept: with flag on, bot gets all reviews on >=4/5 seeds on short+standard, >=3/5 on hard; with flag off all goldens unchanged.
- Tests: demand table per preset; outpost step blocks/clears review; decoy absorbs one audit; flag-off parity.

## K3 — HUD countdown + UI for K1/K2 (owner: view/hud.gd region K3, view/panels/reviews_panel.gd only the display lines marked `# region K3`, tests/test_k3_hud.gd)
- Top-bar chip "Next audit in Nd" (reads `days_to_audit()`, hides if absent), tooltip-free (touch): tap opens existing log/sheet.
- Reviews sheet shows per-preset demands and the outpost step (read-only from K2 getters; guard with `has_method`).
- Accept: button >=64 px, no overflow at 844x390 DPR3 (tools/web_smoke.py PASS), screenshot attached to report; no sim edits.
- Tests: chip text for 0/1/3 days, hidden without audit; layout width check at phone size.

## K4 — tech debt (owner: sim/map/flow_field.gd, sim/logistics/*, tools/belt_bench.gd, tests/test_k4_perf.gd)
- Flow BFS expand speedup: no-belts threats bench 3.0 -> <=2.5 ms (tests/perf_budget.json updated to new budget only after measuring; keep PERF_SKIP_WALL logic).
- Splitter->merger rotation fairness: merger takes inputs in rotating order (round-robin pointer, deterministic) instead of first-come.
- Accept: bench numbers before/after in report; flow results byte-identical (existing flow tests + goldens unchanged); fairness test: two saturated inputs get 50/50 +-2 % over 200 ticks.
- No flag (behaviour-preserving); if the merger change alters any golden, put it behind `k4_merger_fair` default false.

## K5 — power balance + expedition bot (owner: tools/power_model.gd, data/buildings.json power numbers + solar, tools/bot_report.gd, tests/qa_bot.gd expedition helper, tests/test_k5_power.gd)
- power_model.gd: solar output so that 1 solar = 25-35% of a smelter's power_use (now 62.5%); brownout case that hit 59% on one seed must stay >= 75% with a sane build.
- bot_report: bot builds/sends an expedition when conditions are met and completes the Frontier Quota contract.
- Accept: model table in report; Frontier Quota completed on >=3/5 seeds (tools/bot_report.gd output pasted); power numbers behind `k5_enabled` (old values when off).
- Tests: solar/smelter ratio within band from model; bot expedition smoke on seeds 1..5 asserting >=3 completions; flag-off parity.

## Order / merge notes
Merge K1 first (goldens), then K4, K5, K2, K3. Conflict hotspots: data/balance.json (one key per worker), milestone_system.gd (K2 only), hud.gd (K3 only).
Wave done = full suite green x2 + tools/web_smoke.py PASS before merging to main (CLAUDE rule 6/8).
