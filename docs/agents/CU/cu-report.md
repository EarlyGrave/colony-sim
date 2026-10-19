# CU report: rock-bound miner hauling (acceptance NOT met; flags stay OFF)
1. Verified sim bug: haul_blocked_fix (DB) was a HALF fix. HaulGiver gated with can_approach(), but HaulJob still did
   move_toward(b.cell) for Src.BUILDING_OUT; a rock-bound miner cell is not walkable -> find_path empty -> FAILED.
   Now HaulJob walks to best_adjacent() for BUILDING_OUT when haul_blocked_fix is on (sim/jobs/haul_job.gd, flag-gated,
   default OFF => goldens unchanged, no regen). Probe seed 4: copper smelter (52,39) now gets ore and makes ingots (before: cu 0 all game).
2. Bot (tools/factory_bot.gd, region CU): knob pg_bot.cu_first=1 swaps copper line before iron line (default 0). Cause of late copper:
   _build() waits while >= max_pending blueprints are unbuilt; iron line's blueprints held the copper line d6 -> d24 (s4), d17 (s3).
   tools/fc_diag.gd: flags --haulfix --repfix --cu, prints blueprints + bot log.
## 60 d, 10 seeds, jobs=3 (alive>=8 / audit / P1 / P3 / launch)
- baseline (FC): 9 / 8 / 5 / 3 / 1
- haul fix: 8 / 8 / 5 / 2 / 0 (s1,s6 reach "shuttle building"; parts still 0 on s2/s3/s5/s7-10)
- haul fix + cu_first: 8 / 6 / 6 / 2 / 0
- haul + repair_rock_fix: 9 / 4 / 2 / 0 / 0 ; + cu_first: 5 / 4 / 3 / 1 / 0 (2 seeds timed out)
Not run: 90 d (no config passes 60 d).
## Findings
- Haul fix works mechanically (copper ingots appear) but parts stay 0: the assembler is built only after both lines (d25-37)
  and every extra hauling/repair job shifts raids chaotically; repair_rock_fix remains clearly harmful to audit/P1/P3.
- Real remaining lever: bot builds assembler + copper smelter BEFORE slow blueprints (raise max_pending or build smelter first).
  Keep both flags false until then; haul code is now correct for when they are enabled.
Tests: tools/run_tests_quick.sh green (14 passed).
