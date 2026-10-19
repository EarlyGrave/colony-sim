# Y4 report: factory_bot (tools only; goldens untouched)
Done: Scenario.build_chain(sim, true) now returns {blueprints:true, miner_cell} on success (region Y4; test added in tests/test_u4_factory_bot.gd); qa_tutorial_bot comment fixed. PLAN reordered: workbench, miner, essence line, miner, iron line (was iron line at d46, now ~d16-20 on seed 1).
Already in bot (U4): iron/copper smelter lines with dedicated miners (each smelter fed one ore type, recipe picked by inputs, not a sim bug), workbench hand_plate/fuel_cell bills, deliver_audit/deliver_petition/shuttle gantry+parts+turrets, taint cap rule via filters.
Experiments (seed 1, 60 d): hand_plate bill 8 -> 16/35 and cap 50 -> 70 both made it WORSE (hq_destroyed, alive 0-1 vs 8): plates eat the same essence ore as turrets/blueprints; higher cap = more waves. Reverted to bill 8, cap 50.
Root cause: ore stock is 0 all game (d3-d45); every building costs essence_ore (miner 25, smelter 30), the iron miner sat at 20/25 for 30 days. The bot is ore-starved, not plate/recipe-starved; Y3 throughput is the lever. Bot reading the nitrogen node not done (Y1 not merged here).
## Table (60 d, this branch, no Y1-Y3)
| seed | std: audit2/P1-P4/parts/launch | end | alive | pol | --nitrogen=1 end | alive |
|---|---|---|---|---|---|---|
| 1 | -/-/0/- | survived | 8 | 50% | hq_destroyed | 0 |
| 2 | -/-/0/- | colonists_dead | 0 | 51% | hq_destroyed | 0 |
| 3 | -/-/0/- | colonists_dead | 0 | 67% | hq_destroyed | 2 |
| 4 | -/-/0/- | colonists_dead | 0 | 47% | hq_destroyed | 2 |
| 5 | -/-/0/- | hq_destroyed | 2 | 61% | colonists_dead | 0 |
Blocker every seed: audit2 plate -40, parts -10 (plates 0-7 in stock). Target P3>=3/5, launch>=1/5 NOT met; re-run after Y1-Y3 merge. (Table rows measured with the reordered PLAN before the bill/cap experiments.)
