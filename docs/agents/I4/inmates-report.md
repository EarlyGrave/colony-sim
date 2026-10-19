# I4 report: haul_blocked_fix balance pass
Decision: stay OFF (no balance.json / sim change, goldens untouched).

| factory_eval 10 seeds / 60 d | OFF | ON |
|---|---|---|
| alive>=8 at end | 9/10 | 4/10 |
| failures (hq_destroyed/colonists_dead) | 1 | 5 |
| audit tier 2 | 7/10 | 6/10 |
| P1 / P3 | 4 / 3 | 5 / 3 |
| launch | 0 | 0 |
| mean audit day | 39.1 | 35.2 |
Pillar (kx_pillar_table standard_term d21, OFF): baseline 6.2 vs throttle 4.0, gap 2.2 (>= 2 OK).
Rule needs alive>=8 in >=8/10: ON gives 4/10 -> fails. Raid-survival check moot.

Diagnosis (refined bottleneck, with LN's data):
1. OFF refined column per seed 369-1514 over 60 d (~6-25/day, high variance), plates 0-187, parts 0 everywhere: nobody reaches the 24 parts needed for launch.
2. ON hauls more ore out of blocked miner cells but seeds 3/6/10 refine only 48-222 (hq_destroyed early): hauling feeds survival losses, not refinery throughput.
3. Waste stays 250-400 per run, so contamination grows with whatever is refined; the dangerous side is already saturated.
4. Stalls seen in the table: parts/plate stocks 0 at the blocker on 9 of 10 seeds, i.e. the refined output is spent (research, debt, construction per LN ledger) before plates/parts.
5. Not fully traced per ledger sink here; next step is a per-sink dump for one OFF seed with more refineries.

Tests: tests/test_haul_fix.gd asserts the default is false. Needed `godot --import` first in a fresh worktree.
