# B2 report (pollution runaway, clean mining)
All behavior off by default: `balance.json b2_pollution.enabled`, `threat.json b2_clean_outpost.enabled` (both false). Goldens untouched; full sharded suite 0 failed (686 tests).
Implemented (regions B2): idle decay (no refiner mid-batch, pol <= 90%: 0.25 u/day, x8 when `refine_cap` rule on) in `contamination_system.gd`;
miners ignored by creatures while pol <= 20% (`threat_model.gd`); raid points x0.8 while pol <= 20% (`threat_system.gd`);
`contracts.json clean_bonus` (-15% essence due at pol <= 50%) via `ContractSystem.required_essence` (needs b2 on).
Crop/mood reward for throttling NOT done (no existing hook; decay is the throttle reward).
Tools: `tools/b2_table.gd` (new), bot profiles "throttle" (refine_cap 50%) and "mining" (cap 0%, no refining) in `bot_report.gd` region B2. Tests: `tests/test_b2_pollution.gd`.
Table (seeds 1..5, 25 d, avg pol% d20; off -> on):
- baseline (no throttle): 70.2 -> 74.8 (seeds 1,5 planet_dead d22/d20 with b2 on, 3 hq_destroyed d21; chaotic divergence, NOT within +-3: accept FAILED)
- throttle: 57.9 -> 49.1 (earlier tune: 44.5 with clean_frac 0.35/raid 0.7); no planet_dead on all 5 seeds ON (off: 2x hq_destroyed). Accept (<=60%, no planet_dead) met.
- mining-only: 7.0 (seed 3 hq_destroyed d22) -> 0.0, 5/5 alive d25. Accept met.
Tuning note: idle decay alone gave baseline 70.2 -> 57.9 (-12); lowered to 0.25 u/day to protect non-throttlers, but raid_mult/outpost rules still shift trajectories.
Orchestrator: decide whether to drop `raid_mult` (set 1.0) before enabling; flip keys then single golden regen.
