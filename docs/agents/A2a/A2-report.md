# A2a report: miner / smelter / assembler
Branch a2a (from c037bec), not pushed.
- Building (region A2a): station_recipes/station_defs (processor recipes whose `station` lists the building, sorted ids), node_cell, mach_acc, mach_items; is_machine() now includes `machine`; input_space accepts any station-recipe input.
- BuildingSystem (region A2a): tick_machines() (called in Simulation.step after logistics.tick); placement lets on_node buildings cover node (deposit) cells, needs >=1 node.
- Miner: acc += NodeData.rate(res,purity)/100 per tick (10/100 ticks normal, 5 impure, 20 pure) into output buffer (cap 20, stalls when full, no loss); ledger source "mining". Wear: wear_per_batch per `batch_items` (10, new key in buildings.json) items.
- Processor (smelter/assembler): when idle picks first station recipe (sorted id) that can run; runs through existing work() with operator null, so waste, batch_refined (per_batch contamination), wear, broken, refine_cap and crisis lock behave exactly like the hand refinery. No inputs -> idle, nothing lost. Smelter also refines essence (recipe station list).
- Output stays in the building output/input buffers: belt <-> buffer transfer is A2b's job; colonists do not operate machines.
- buildable:true for miner, smelter, assembler.
- tests/test_machines.gd: 7 tests (rates by purity, needs node, idle/smelt, waste+contamination equal to refinery, assembler chain, wear/broken stop), all pass.
