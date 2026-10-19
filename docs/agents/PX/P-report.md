# PX report: debt regressions
Findings: the "escape" diagnosis was wrong. Seeds lost colonists to RAIDS (factory_bot paid installments before the turret reserve; debt.gone was 0). Also factory_bot's `died` counter was always 0 (lambda captured an int by value) -> fixed (array), plus `gone=` printed.
Changes:
- sim/debt/debt_system.gd + data/debt.json: `grace_days` 10 after a missed installment before despair starts; despair/day scales with unpaid share (partial payment slows it). Debt size/interest unchanged (still almost unpayable).
- tools/factory_bot.gd: installments keep the turret floor (floor_keep).
- data/balance.json pacing.pollution_interval.dirty_mult 0.5 -> 0.35 (dirty baseline waves faster; gap restored).
Pillar (kx_pillar_table --days=21 --seeds=5, standard_term; "standard" preset ignores the pacing knobs): before baseline 5.8 / throttle 4.0 (gap 1.8 per D) -> after 6.2 / 4.0 (gap 2.2).
factory_eval 10 seeds 60 d (alive>=8 / P1 / P3 / debt max):
 before PX (D): 6/10, 4, 4, 6-31%
 grace only:    7/10, 4, 4, 29%
 + bot reserve: 8/10, 4/10, 4/10, max 29% (PASS targets). audit2 7/10; remaining losses seeds 2,3 = hq_destroyed (raids, not debt).
Tests: test_debt adapted (grace 0 in despair-ramp tests, d1 test includes grace) + new test_px_grace_*; full suite 822 passed 0 failed; goldens unchanged; web_smoke PASS.
Note: factory_eval_summary "alive8" prints ==8 (not >=8); my count uses alive>=8.
