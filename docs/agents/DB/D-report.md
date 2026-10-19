# DB report: heavy debt
Debt: 120-280/inmate (8 inmates ~1600) + 3% interest per 10-d period; installment 4/period/inmate, first deadline d25; missed -> +4 despair/day, break at 50 (data/debt.json, sim/debt/debt_system.gd: period_paid, interest in DebtState). Model (tools/debt_model.gd): before payoff d44, after d60 paid 18%, never paid off.
Bot: pays installments first, extra to least-paid inmate (factory_bot, bot_report).
Fix 2 (haul from blocked miner): done + test, but behind balance `haul_blocked_fix` (default false): ON dropped survival (alive8 0-1/10, hq_destroyed). Fix 3: blueprints take loose essence ore (deliver_materials_giver) + test. Tests: tests/test_db_fixes.gd, test_debt updated.
Eval 10 seeds 60 d (before -> after): alive8 9/10 -> 6/10 (alive>0 9/10 -> 9/10; losses are inmates escaping); audit2 6 -> 6; P1 1 -> 4; P3 0 -> 4; P4 0 -> 3; debt paid 100% -> 6-31% (mean ~15%); launch 0 -> 0.
Pillar d21: baseline 5.8 / throttle 4.0 -> gap 1.8 (<2, was 3.4; not caused by loose ore, checked).
Suite 813 green x2, goldens regenerated (debt rng), web_smoke PASS.
Open: alive8 drop (escapes; bot pays only when refined is in stock; seeds chaotic +-2); pillar gap 1.8 needs a pollution/bot_report pass.
