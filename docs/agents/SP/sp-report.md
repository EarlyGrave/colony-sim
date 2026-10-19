# SP report: where refined/plates go (launch still 0/10)
Acceptance NOT met: launch 0/10, audit tier2 7/10 (ok), alive>=8 at end 9/10 on all seeds (table col), P3 3/10, P1 4/10.

Ledger sinks (seed 7 / 5 / 8, 60 d), essence ore: mined 967/2061/1876; construction ~510-540; recipes 365/575/896; rest idle in stock (seed 3: 533, seed 8: 381-519).
Refined REAL production (recipe) only 114/186/264 (seeds 7/5/8); the "refined" table column is inflated by research refunds (240-1250, net zero).
Real refined sinks: debt 76-144, petition 15-77, review 90, construction 21-84. Research nets ~36-40. So the spend priority is not the leak.
Plates: hand_plate (3 ore each, ONE workbench) made only ~150 per 60 d; assembler make_parts built 81 parts (36 used) = ~45 plates wasted into parts stock; repairs ~40.
Changes (tools/factory_bot.gd, regions SP): (1) _cap_parts: parts cap 11 before audit, 21 until P1, then 25; (2) hand_plate bills on every workbench, target 70 once ore stock >= 80; (3) 2nd workbench when ore >= 80 (never got built on seed 8: spot/priority, unresolved); (4) ledger also dumps :essence_ore sources.
Result (10 seeds/60 d, --jobs=3): audit 7, P1 4, P3 3, launch 0; seed 5 P4 short 16 refined (was 63), seeds 1/7 short 76.
Cap tests: --cap=50 more refined but alive worse, no launch; --cap=100 seed 1: refinery makes 156 (vs 102 at 35) and pollution 100% -> the throttle is not the cause.
Root cause: refinery duty cycle. Seed 1 two refineries = 17 batches/60 d (capacity ~1400 batches); 400-900 ore idle in storage. Ore-to-refinery logistics (hauling into the 20-slot input, refinery wear/broken, worker priority) limit output, not spending.
Missing quantity: launch needs ~24 parts + 8 fuel cells + P1 60 plates + P4 60 refined = ~3x current real refined (~300 vs 100-260) and ~2x plates (hammer 150 -> 300). No data/balance change (pillar table untouched, goldens untouched).
Next: trace refinery input feeding / haul jobs (why 400+ ore sits while the refinery idles), or add a second hand_plate worker; find why workbench #2 placement fails.
Quick tests: 14 passed, 0 failed.
