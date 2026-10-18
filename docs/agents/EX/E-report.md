# EX reconcile report (E1..E5 merged)
- UI aligned to real APIs: `get_petition_state()` (+`deliver_petition(phase)`, 1-based; added `reward` text to state rows), `get_sector_state()` + `dispatch_sector(tier, modifier_id)` (state rows now carry `have`; one "Ship: <modifier>" button per unused modifier, disabled until `available`), reviews panel uses `milestones.e3_rank_title()/e3_range_score()`. No has_method guards. HUD: Petition button only when a phase is open/done, Dispatch from day 4. tests/test_e4_ui.gd rewritten (real sim on/off + stub in real shapes).
- `e1_enabled`, `e2_enabled`, `e3_enabled` now true. Tests that pinned old 3-review/off-default behaviour set e3 off explicitly (b3/k2/e1/e3).
- E2 bundles: T1 200 food, T2 130 food + 6 refined, T3 60 essence_ore (a plain bot's food dies out after ~d17; ore piles up late). bot_report --days=30 --seeds=5 --e2:
| seed | T1 | T2 | T3 |
|---|---|---|---|
| 1 | d7 | - | - |
| 2 | d7 | d17 | - |
| 3 | d8 | d16 | d23 |
| 4 | d7 | - | - |
| 5 | d5 | d16 | - |
  T1 5/5 (d5-8), T2 3/5 (d16-17), T3 1/5.
- E3 retuned (data/milestones.json): R4 "debt left < 75%" (was 5%), R5 range score >= 50 (was 150). review_bot got `--power` (2 coal generators + pole, hand-fed coal, electrification granted). 40 d, seeds 1-5:
| mode | R1-3 | R4 | R5 | best range per seed |
|---|---|---|---|---|
| plain --e3 | 5/5 | 5/5 | 0/5 | 0 |
| --e3 --power | 5/5 | 4/5 | 1/5 | 114/64/69/82/48 |
- E1 petition_bot (scripted supply, not real production), standard 40 d, all flags on: P1 5/5 (d13-14), P2 5/5, P3 5/5 (d18-21), P4 1/5 (seed 3 d29; others die first, d28-34). Meets P1 5/5, P3>=3, P4>=1.
- Goldens: `make_golden --regen` run, 0/30 hashes changed in all 8 scenarios (nothing to commit).
- Screenshots 844x390: docs/agents/EX/petition.png, dispatch.png (tools/screenshot.gd `--panel=petition|dispatch` demo state).
- Verification: --import, run_tests_sharded 735 passed 0 failed twice in a row, web_smoke PASS. No background runs left.
