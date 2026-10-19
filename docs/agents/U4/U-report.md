# U4 report: real production bot (tools/factory_bot.gd, tools/factory_bot_report.gd, tests/test_u4_factory_bot.gd)
Public commands only (place_building blueprints, place_belt, add_bill, queue_research, deliver_*); no spawning, no place_instant. Taint cap = research `filters` + `refine_cap` 50%. Sharded suite: 760 passed, 0 failed.
Run: `godot --headless --path . -s tools/factory_bot_report.gd -- --days=60 --seeds=5 [--log --nitrogen=1]`
| seed (60 d, standard) | factory bot (real) | scripted shuttle_bot |
|---|---|---|
| 1 | no audit2/P1-P4; plate 16 total; 8 alive; pol 50%; food 550; survived | P1-4 d14/15/18/32, launch 36.5, won, 8 alive, pol 73% |
| 2 | colonists_dead; plate 8 total; 0 ingots | P4 d33, launch 36.5, won |
| 3 | hq_destroyed; 1 assembler, coal line d36; 0 plates | P4 d25, launch 29.5, won |
| 4,5 | not run in the final tuning round (3 seeds, 20-40 s each) | P4 d31 / d35 (S-report) |
Shuttle parts 0/24, launches 0 for the real bot on every seed.
## Bottlenecks (in order)
1. HARD BLOCKER: nitrogen exists only on the outpost biome `vents` (0 nitrogen nodes on all 5 home maps, tested). P3 (20 nitrogen) and every fuel cell (24 x 2) are impossible without an expedition/sling chain, so P3/P4/launch are unreachable on the home map. Scripted bots hide this with a nitrogen trickle. `--nitrogen=1` scripts it (experiment only).
2. Plates gate everything: broken machines need 2 plates to repair (balance machine_repair_cost); smelters/miners break within days. Without a workbench `hand_plate` bill the line dies (refined 3/day).
3. Early economy: ~1000-1500 ore in 60 d, 150-250 refined; debts + turrets (10 each) + research (refined essence) eat it; iron line only at d10-46 and iron ingots never smelted (smelter ends up on essence ore / stays broken), so audit2 (40 plate + 10 parts) is not reached.
4. Survival: debt despair escapes and hq_destroyed on 2/3 seeds.
## Factory bot section
Layout: hand-hauled essence miner (d2), miner->belt->smelter->belt->storage_in lines (essence refine, iron, copper, coal) with BFS-routed belts, coal generators + pole chains, 3 assemblers, workbench (hand_plate, fuel_cell bills), warden terminal, 2nd refinery, turret blueprints. Fails: ore starvation early, machine wear without plates, iron smelting stall, no nitrogen.
Side finding: Scenario.build_chain(blueprints) returns {} on success, so the tutorial bot spawns ~7 chains (this bot cancels the extras).
