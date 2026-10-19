# FC report: bot shuttle fix (tools only; no sim/data/golden change)
Root causes in tools/factory_bot.gd (region FC):
1. Gantry was only placed when `_step >= _plan.size()` and no blueprint pending; after P4 the bot kept laying iron lines, so seed 5 (P4 d41) never built the gantry by d60 (parts 0/24, 8 idle fuel cells).
2. Fuel-cell bill (shuttle branch) required `parts >= need` first, but delivered parts CONSUME fuel cells (circular); bill target was 8. Now no parts precondition, target 24 (knob pg_bot.fc_bill), gantry no longer waits for the plan (knob fc_gantry=1).
Refined spending: `_hoarding`/stop_research already reserve refined after P3; no further sinks found.
Parts stall (s3/s4/s6): not an assembler bug. Probe tools/fc_diag.gd (seed 4): assembler input just buffers 8 plates + 8 refined (normal hauling); `make_parts` needs 1 plate + 1 ingot_copper and copper ingot stock is 0 all game: the copper miner (50,41) sits full (20 copper_ore in output) with no smelter/belt and nobody hauls it (rock-bound miner = haul_blocked_fix case). So parts are copper-starved, not a recipe loop.
## Results (factory_eval jobs=3)
60 d, flags off + bot fix: launch 1/10 (s5 won, parts 24/24), alive>=8 9/10, audit 8/10, P1 5/10, P3 3/10 -> acceptance MET (baseline launch 0/10).
90 d: launch 1/10 (s5), alive>=8 6/10 (s1 alive 3, s2/s7 dead, s3 hq), audit 8, P1 8, P3 4, s1/s9 reach "shuttle building".
## Flags (10 seeds, 60 d, with bot fix)
- repair_rock_fix ON: alive>=8 8/10, audit 5/10, P1 2, P3 0, launch 0 -> keep OFF.
- haul_blocked_fix ON: alive>=8 8/10, audit 6, P1 5, P3 3, launch 0 (s5 loses its launch) -> keep OFF.
Recommendation: both stay false. Real next lever: bot should build/repair the copper line (or hand-haul stuck miner output) on s3/s4/s7/s10; seeds 1/9 need ~10 more days post-gantry.
Tests: tools/run_tests_quick.sh green (14 passed). Goldens untouched.
