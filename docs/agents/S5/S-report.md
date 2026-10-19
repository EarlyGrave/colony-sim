# S5 report (partial: bot + sustain + ending text; shuttle tuning blocked on S1)
Root cause of "planet dead d28-34": stockpiled waste (refining output) emits pollution forever; the old bot never turned the Taint cap on.
Fix in bot: grant research "filters" + `refine_cap` rule at 50% (`--throttle=1` default; `--throttle=0` reproduces death).
Bot: `godot --headless --path . -s tools/shuttle_bot.gd -- --days=60 --seeds=5 [--trace --throttle=0 --cap=50]`
| seed | P4 day | colonists d60 | pollution d60 | end |
|---|---|---|---|---|
| 1 | 42 | 2 | 75% | survived |
| 2 | 37 | 6 | 74% | survived |
| 3 | 31 | 8 (food 0) | 74% | survived |
| 4 | 36 | 5 | 74% | survived |
| 5 | 34 | 7 | 75% | survived |
Without throttle: 5/5 planet_dead d28-34. P1-P3 5/5 (d13-21), P4 5/5 (d31-42).
Open: food declines late (seed 3 food 0 at d59; more farming would help); launch/siege/win columns print "-" until S1 merges.
Assumed S1 names (bot skips if absent): `Simulation.get_shuttle_state()` {phase ready/won}, `launch_shuttle()`, balance `s1_enabled`/`s2_enabled`, item `release_part` (scripted supply 4/day from d12; skipped if item undefined). Orchestrator: adjust SUPPLY to the real part inputs.
Added: `data/flavor.json` `shuttle_ending.text` (4 lines, 42 words), `data/balance.json` `s5_shuttle_bot` targets, `tests/test_s5_bot.gd`.
Not done: shuttle cost tuning, siege win rate, beacon debt cut (need S1/S2 merged). Goldens NOT regenerated: nothing in sim changed, flags still off; regen once after the orchestrator flips s*_enabled.
Tests: 737 passed, 0 failed (sharded).
