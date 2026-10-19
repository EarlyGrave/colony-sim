# D1 report: debt pacing
Design intent (decided without owner, review): debt stays the core pressure, but a decent factory (~7 refined/day ramping from d8) pays it by ~d40-50.
Change (data only, data/debt.json): debt 30-90 -> 14-42, due_days 12 -> 30, despair_per_day 10 -> 8. Idle colony: due d30, break despair (40) from d35.
Model: tools/debt_model.gd (8 colonists: expected debt 480 -> 224; payoff day 81 -> 44; 6 colonists -> d36).
Tests: tests/test_debt.gd (food stock raised for 30 d runs; overdue test +6 d; new region D1 schedule + zero-payment-still-breaks test). Sharded suite: 776 passed, 1 failed (the overdue test, since fixed; test_debt 16/16).
Goldens: make_golden --regen changed 0 hashes in all 8 scenarios (nothing to commit).
Pillar (kx, d21 standard_term): baseline 7.4, throttle 4.0 -> gap 3.4 (>=2 holds).
Harness (10 seeds, 60 d, real bot): debt paid ~100% on 8/10 (was 26-69%), alive 8 on 6/10; refined 318-468. Still audit2/P1/P3/launch 0/10: plates 0-8, parts 0, waste 150-250 -> planet_dead x3, colonists_dead x2 (not debt now) -> needs D2 sink + D3 plate reserve/assembler.
Files: data/debt.json, tools/debt_model.gd, tests/test_debt.gd.
