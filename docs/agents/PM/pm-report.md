# PM report: plates vs refinery under smelt cap_margin 0 (acceptance NOT met; data unchanged)
Change kept: sim/jobs/givers/haul_giver.gd - the ore_reserve rule (meant to shield plates from the refinery) also blocked the workbench
from taking stored ore; workbench is now exempt. Quick tests 14/14. Goldens untouched (data unchanged).
Data: cap_margin stays 30 (margin 0 tried, reverted).

Tables (10 seeds, 60 d, --jobs=3; real refined s1/5/7; alive>=8; audit; P1; P3; launch):
- margin0 cap50 (before fix): 312/474/252; 9/10; 6; 2; 1; 0. plates ~0 on 7/10 seeds.
- margin0 cap50 + workbench exemption: 330/372/252; 8/10; 6; 3; 1; 0.
- + bot reserve 150 / plate_low 90 / high 140: 312/408/252; 8/10; 6; 3; 1; 0 (seed 6 planet_dead).
- margin0 cap70 + exemption: 336/396/234; 7/10; 7; 4; 1; 0 (2 hq_destroyed).
Baseline (margin 30 cap 35): 102/186/114; alive 10/10; audit 7; P1 4; P3 3; launch 0.

Finding: plates are not only starved by the refinery. With margin 0 the smelters also stop at the taint cap, so ingot_iron starves
(P2 blockers on seeds 5/6/7) and parts stay 0; the whole chain shares one pollution budget, refinery output rises 2-3x but P3 drops to 1/10.
Seed 9 (pol 0%, 108 refined) is stuck for another reason (not investigated).
Not done: kx_pillar_table gap check (no data change). rf_diag.gd hangs with --margin/--cap on seed 5 (no output after 25 min).
Next idea: separate cap for smelters (cap_margin>0 only while ingot stock < N), or less polluting smelting so both fit under cap 50.
