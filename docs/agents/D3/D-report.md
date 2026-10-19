# D3 report: factory_bot (tools only; goldens untouched)
Changes (tools/factory_bot.gd): PLAN reordered (refinery, iron+copper smelting lines, assembler before essence line/terminal); research queued early (filters, assembly, electrification; fortification+decoys_1 later); plate reserve 12 (hand_plate bill floor once assembler planned; fuel_cell bill only when parts done and plates >= reserve+4); debt paid FIRST each upkeep from refined (floor 10 for one turret), before contracts/research; ash beacon built after decoys_1; waste_compactor x3 when balance flag waste_sink_early is on (works with flag off).
Assembler chain built d28-40 (seeds 1,3,5: d29.7/d28.4/d39.5); target d25 NOT met (research bench time: smelting+storage_ports+assembly ~8100 bench ticks).
## 10 seeds, 60 d (factory_eval.sh)
Baseline (D4): plates 0-8, parts 0/24, audit/P1/launch 0/10.
After, flag off: planet_dead 5/10, refined 274-526, plates 0-12, parts 0/24, 0/10 audit.
After, flag on: planet_dead 2/10, ok 4/10 (pollution 11-66%), refined 354-768, debt paid up to 100% (seed 3), parts 0/24, 0/10 audit.
Takeaway: survival, debt and pollution improved (flag on helps a lot); parts/plates still ~0: repairs eat plates as fast as made, assembler arrives late, smelters starve. Next: sim-side repair plate cost / assembler priority, or earlier research.
Suite: 777 passed, 0 failed (before merging D4/D2 branches).
