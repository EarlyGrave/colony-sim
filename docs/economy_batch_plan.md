# Economy batch Y (one wave, 5 workers)
Goal: tools/factory_bot.gd (public commands only, no scripted supply) reaches Petition P3 on >=3/5 seeds and a shuttle launch on >=1/5 in 60 d, standard preset. Baseline: P3 0/5, launch 0/5 (U4 report).
Table tool: `godot --headless --path . -s tools/factory_bot_report.gd -- --days=60 --seeds=5`. Pillar gate: `tools/kx_pillar_table.gd` throttle >= 2 waves below baseline on standard.
Common rules: start `git reset --hard claude/colony-sim-godot-4jftsm`; shared files only in `# region Y<n>`; sim/ deterministic; all data in JSON; every balance change shows before/after factory_bot table (seeds 1-5, 60 d) in the report; never `pkill` broadly, no background runs left, temp files via `mktemp -d` only; commit in worktree, no push; report <=30 lines in docs/agents/Y<n>/economy-report.md.
Golden policy: ONLY Y1 regenerates goldens (`tools/make_golden.gd -- --regen`, last step, after Y2/Y3 data is merged-in-mind: Y1 states the exact changed ticks). Y2/Y3 must keep goldens identical or gate the change behind a new flag/preset key (default off in golden scenarios) and say so.

## Y1 Nitrogen on the home map (owns data/biomes.json, sim/map/map_generator.gd region, tests/test_y1_*.gd, tests/golden/*)
- Add nitrogen to start biome `extra_resources` (small vent node, 1-2 per map, ~600 units each, reachable without expedition) on all 5 seeds; fallback: recipe nitrogen from an existing item (e.g. refined waste/coal) in data/recipes.json if map change breaks seed layouts.
- Acceptance: nitrogen node exists on seeds 1-5 within start region; P3 (20 N) and fuel cells (24x2) are sourceable; map gen stays deterministic; threat bench unchanged.
- Tests: node count per seed, reachability from HQ, determinism. Regenerate goldens (sole owner), list changed ticks in report.

## Y2 Repair / plate economy (owns data/balance.json repair keys, data/recipes.json hand_plate, sim/buildings recipe-selection region, tests/test_y2_*.gd)
- Diagnose from `--log`: why broken machines stay broken, why the iron smelter ends on essence ore / never smelts iron (recipe selection vs bot placement). Fix in sim only if it is a real bug (add test), else hand to Y4.
- Make hand_plate available/cheap early (first workbench, no research), tune machine_repair_cost / wear so plates supply > repair demand in d1-20.
- Acceptance: bot machines broken-time <15% of ticks seed 1-5; plates produced >= 40 by d20; table shows plate totals before/after.

## Y3 Throughput, debt, HQ losses (owns data/balance.json non-repair keys, data/rules.json, tests/test_y3_*.gd)
- Tune data only: ore yield/miner rate, refine ratios, turret cost (10), research refined cost, debt despair escape threshold, HQ HP/regen, early raid size, so ore >=2.5k and refined >=500 over 60 d for the bot; colonists_dead / hq_destroyed on <=1/5 seeds.
- Acceptance: table of ore, refined, plates, debt%, alive, end reason per seed before/after; pillar table gate passes (throttle >=2 waves below baseline); no change to mining-only baseline outcome beyond noise.
- Coordinate with Y2 via disjoint keys: Y2 repair/wear keys, Y3 everything else.

## Y4 factory_bot improvements (owns tools/factory_bot*.gd, tests/test_u4_factory_bot.gd, tests/scenario.gd region Y4)
- Fix Scenario.build_chain(true) returning {} on success (callers/tutorial bot spawn ~7 chains); add test.
- Add iron ore -> ingot line (smelter with iron recipe fixed, not essence), copper, plates via workbench bills (hand_plate, fuel_cell, parts), audit-2 / petition feed through public deliver_* commands, shuttle gantry + parts + turret defence.
- Bot reads nitrogen node (after Y1 lands; use `--nitrogen` flag only until then), sets Taint cap rule.
- Acceptance: table adds columns audit tier, P1-P4 day, parts, launch; runs 5 seeds <=3 min. Final integration run after all branches (orchestrator merges, Y4 re-runs the target check: P3 >=3/5, launch >=1/5) and reports the gap if missed.

## Y5 UI leftovers (owns view/hud.gd regions, view/build_popup*.gd, view/modal_layer*.gd, tests/test_y5_*.gd)
- Belt entry in Build popup (touch >=64 px, same flow as build tools).
- HUD game-over box through ModalStyle (opaque card, scrim, filled primary button).
- Scrim in ModalLayer behind side sheets (tap scrim closes).
- Acceptance: tests for each; world visible >=55% at 844x390 still passes; screenshot via tools/screenshot.tscn in report.

## Orchestrator after wave
Merge Y1->Y2->Y3->Y4->Y5, rerun table + pillar table + full sharded suite x2 + tools/web_smoke.py, update PROGRESS/DECISIONS, merge to main only if green.
