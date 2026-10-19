# Y2 report: repair / plate economy
Changes (data only, goldens untouched; sharded suite 768 passed, 0 failed before adding test_y2): balance line_damage.machine_repair_cost plate 2 -> 1; recipes hand_plate essence_ore 6 -> 3, work_ticks 90 -> 60 (already workbench-only, no research; gated only by b4_enabled=true in balance). tests/test_y2_repair_plates.gd.
## Diagnosis (temp trace of smelters, bot seed 1, 60 d)
- Broken machines are NOT the bottleneck: miner+processor broken-time 1-3% of ticks (<15% OK). Plate ledger shows 0-2 plates consumed in 60 d, repairs barely happen.
- Iron never smelted is NOT a recipe-selection bug. Cause chain: (1) first bot "line" is essence_ore with a smelter; the smelter accepts essence_ore (refine_essence is a smelter station recipe), colonists/belts fill it with essence and it refines; (2) every smelter recipe (smelt_iron/copper too) outputs waste, which `contaminates`, so `refining_capped()` (bot Taint cap 50%) blocks ALL of them once pollution >= 50%; smelters end holding iron_ore 20 + essence_ore 20, recipe empty. I prototyped skipping capped refine recipes in selection: no effect (iron also capped), so reverted.
- Handed to Y4: do not put a smelter on the essence line (use plain belt to storage/refinery), keep iron smelter fed only iron ore, and/or raise cap above 50% or pace refining so smelting waste fits; bot hand_plate bill is `until 8`, which is why plates total only 8-22; raise to ~30-40 for >=40 plates by d20 (not my file).
## Table (factory bot, 60 d; plates produced/consumed; before -> after)
| seed | plate before | plate after | end after |
|---|---|---|---|
| 1 | 16/0 | 20/2 | hq_destroyed |
| 2 | 8/0 | 8/0 | survived |
| 3 | 4/0 | 10/1 | hq_destroyed |
| 4 | 9/5 | 22/0 | survived |
| 5 | 7/0 | 9/0 | hq_destroyed |
Plates >= 40 by d20 NOT met: bound by the bot bill target (Y4), not by recipe cost.
