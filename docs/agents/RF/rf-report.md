# RF report: refinery duty cycle (acceptance NOT met; root cause found)
Sim/data/goldens untouched. Built on SP's branch.

(1) alive>=8 discrepancy: the table "alive" column is the end count (8 or 9); the summary line used `alive == 8`, so 9s were not counted (3/10).
Fixed in tools/factory_eval_summary.py (now `>=8`; new column `real` = recipe-source refined, no research refunds).
TRUE alive>=8, SP bot, seeds 1-10, 60 d: 10/10. The claude/colony-sim-godot-4jftsm bot was not re-run (same harness, SP only added bot logic).
SP bot baseline: audit 7, P1 4, P3 3, launch 0; real refined s1/5/7 = 102/186/114.

(2) Root cause (traced with tools/rf_diag.gd): NOT hauling/wear/power/priority. The refinery is blocked by the taint cap (~70% of samples,
input full 20/20, 400-900 ore idle). Smelters have recipe cap_margin 30: they keep running up to cap+30 and hover pollution at 65 while the
refinery stops at the cap (35). In the hover only smelter batches pollute (seed 1 d36-40: +30 pts in 4 d); b2 decay is blocked while any
smelter/refinery is mid-batch, so the refinery gets only short windows. Refined output = leftover pollution budget.
Workbench #2 exists on seed 1; SP's "never placed" was seed 8 (ore<80 gate / spot). Not the bottleneck.

Experiments (real refined s1/5/7; baseline 102/186/114):
- bot dismantles smelters when ingot stock >= hold and capped, rebuilds when low: 144/378/138, but ingots starve (P2 fails), rebuild loses belt routes, hq_destroyed on s5. Reverted.
- ingot stock_cap on smelt recipes (--ov): no effect (iron is consumed as fast as it is made).
- smelt cap_margin 4/12: identical to baseline (the cliff is at <= 0). margin 0 + cap 35: 246/276/240 but plates 0-31, deaths.
- margin 0 + --cap=50, 10 seeds: real refined 108-498 (s1/5/7 = 312/474/252, 2.2-3x), alive>=8 9/10, audit 6/10, P1 2-3/10, P3 1/10, launch 0.
  Seed 1 reaches P4 and "shuttle building parts". Plates are ~0 on most seeds: the refinery eats all loose ore, hand_plate (3 ore) starves.
- bot _rf_reserve (ore_reserve rule while plates < 30): no help; left OFF (knob pg_bot.rf_reserve=1 enables it).

Conclusion: the refinery runs 2.5-4x only if smelters stop at the same cap (margin <= 0), and then plates (ingots + ore) become the wall.
Not done / next: a plate source that does not compete with the refinery under margin 0 (check workbench operator priority and bill target
when ore stock is 0), then change data/recipes.json cap_margin, regen goldens and re-check the tools/kx_pillar_table.gd gap >= 2.
Committed: tools/factory_eval_summary.py, tools/factory_bot_report.gd (real field), tools/factory_bot.gd (region RF, default off), tools/rf_diag.gd.
Quick tests: not run (tools only; no sim change).
