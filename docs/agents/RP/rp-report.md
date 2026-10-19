# RP report: remote miner repair + shuttle gap (acceptance NOT met; real sim bug found, gated off)
Root cause: NOT plates. Wear-only repair is free (plates are charged only when hp < max_hp). RepairGiver used pathfinder.reachable(colonist, b.cell),
but miners sit on ore-node cells that are rock (is_walkable false: 6 of 10 miners on seed 1), so reachable() was always false: such a miner was
never offered a repair job (and RepairJob.move_toward(b.cell) could not path either). Seed 1: miner (28,47) broken d24 -> d60, 18 ore stuck in buffer.
Fix (sim, balance flag repair_rock_fix, default OFF): giver uses can_approach(); job walks to best_adjacent() cell. Probe: tools/rp_diag.gd (--seed --days [--fix]).
Effect on iron_ore produced / 60 d (baseline -> fix): s1 1929->3187, s5 712->1464, s7 540->1146 (about 2x).
BUT 10 seeds/60 d, jobs=3 (alive>=8 / audit / P1 / P3): baseline 9/10, 8, 5, 3 -> fix 8/10, 5, 2, 0 (s2 dead, s3 hq_destroyed, s4/5/6 lose audit);
fix + bot repair prio 2: 8/10, 5, 1, 0. Runs are chaotic (extra repair/haul load shifts raid timing; parts stay 0 on s3/4/6 despite 700 plates on s4).
So the flag stays off (same pattern as haul_blocked_fix); goldens untouched, data change is a new false key only.
Not done: bot plate reservation for repairs (pointless: repairs of worn miners cost no plates). Next: pair repair_rock_fix with haul_blocked_fix and
a parts-stall fix (assembler on s4 holds parts in input, parts 0 in stock; audit2 needs 10 parts) before enabling.

## Exact gap to shuttle launch (day 60, baseline flag off; "fix" = repair_rock_fix on)
Need (24 release parts + gantry): plates 24*(2+1 fuel cell)=72 +40 gantry =112; refined 24; nitrogen 48 (fuel cells); fuel_cell 24; parts 10 (gantry) ; 2 d countdown.
| seed | refined (have/24) | plates (have/112) | parts (have/10) | nitrogen (/48) | fuel cells (/24) | gap in days |
|---|---|---|---|---|---|---|
| 1 | 2 / 24 -> need 22 | 716 ok | 29 ok | 104 ok | 8 -> need 16 | refined is the wall: ~0.4 refined/day, 22 more = >55 d |
| 5 | 262 ok | 135 ok | 30 ok | 134 ok | 8 -> need 16 | only fuel cells (16 x 90 ticks workbench) + 2 d: a few days; launch blocked by gating (tier_done) not stock |
| 7 | 10 -> need 14 | 47 -> need 65 | 18 ok | 190 ok | 0 -> need 24 | plates ~+65 and refined +14: ~25-30 d at current rates |
With fix: s1 plates 578, refined 2, fuel 0, N 0; s5 plates 647 refined 3 N 0 (tier2 not done); s7 plates 214 refined 2 fuel 0.
Takeaway: shuttle is limited by refined_essence (s1/s7) and by fuel-cell crafting + nitrogen, not by plates once the miner works.
