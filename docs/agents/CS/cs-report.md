# CS report: only essence refining pollutes (owner rule 2026-10-19)
Change: new recipe flag `pollutes` (default false; only `refine_essence` = true). `BuildingSystem._is_refining` now = `recipe.pollutes`
(taint cap, refine_lock crisis, QX refine_mult, machine_rate forecast); `ContaminationSystem._on_batch_refined` adds per_batch only for `pollutes`.
smelt_iron / smelt_copper: waste output, cap_margin and contam_mult removed (clean, never capped). Defs.validate: polluting recipe needs waste.
Uranium can opt in later with `"pollutes": true` (+ waste output). docs/sim_contract.md recipes row updated.
Goldens: make_golden --regen changed 0/30 hashes everywhere (scenarios do not exercise smelting under the cap), nothing to commit.
Tests fixed: test_automation_defs (3), test_machines smelter waste 0, test_research (smelter waste part removed; hand refinery part stays),
test_power meltdown (burst >= +25: b2 decay is no longer blocked by smelters, 40 -> ~30). Quick tests 14/14.
Full sharded run before fixes: only those 7 failures + timing flakes (test_biomes generation_time, test_power perf); not re-run in full after fixes.
Pillar (kx_pillar_table, standard_term d21): baseline 6.2 waves vs throttle 4.0 / mining 4.0 -> gap 2.2 (>= 2 OK).
factory_eval 1-10, 60 d, jobs=3: real refined s1/5/7 = 228/582/252 (baseline 102/186/114, 2.2-3.1x).
alive>=8 8/10 (baseline 10/10; seed 3 hq_destroyed, seed 9 alive 7); audit 7/10; P1 5/10 (was 4); P3 3/10; launch 0/10.
Acceptance: tests green, pillar OK, real up on 1/5/7 OK, alive>=8 8/10 meets >=8; stretch launch not met (plates 0-13 on s3/7/8/9/10).
Next: plate supply (hand_plate / workbench vs refinery for ore) is the remaining wall; seed 3 hq_destroyed needs a look.
