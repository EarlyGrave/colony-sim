# L5 report: data + research + balance + QA (Logistics 2 / power)
Committed in the worktree, not pushed. Sharded suite x2 "0 failed" (643 passed); the 8 goldens are byte-identical.

## Landed (data first)
- `data/fuels.json` (new, `Defs.fuels`): coal T1 (gen 100, 2 waste/burn, threat 15), nitrogen T2 (turbine gen 240, 1 waste/burn, threat 10), uranium T3 (reactor gen 800, 1200-tick burn, 1 waste/burn, `spent_fuel` 1/burn, `meltdown{}` data), solar block. Essence is never fuel. energy_per_unit = gen*burn_ticks/10, checked by test.
- Buildings: power_pole (range 6), coal_generator, nitrogen_extractor (on_node, node_resources [nitrogen], power 20), nitrogen_turbine, nuclear_reactor (3x3, in/out ports), solar_array (gen 25, fuel null). `power_use`: miner 20, smelter 40, assembler 50, research_bench 20 (+10/chip = `balance.power.chip_power_use`). Splitters/mergers are belt nodes, no building defs.
- Items coal, nitrogen, uranium, spent_fuel (contaminates, half_life_days 30; accepted ONLY by waste_dump). Resources coal/nitrogen/uranium use `appended: 2` (NodeData orders them after R4a, so bytes 1-6 never shift; coal=7, nitrogen=8, uranium=9). Biomes: `vents` (nitrogen), `irradiated` (uranium); start gets `extra_resources {coal}` (start weights untouched).
- Techs (5, own block at the end of research.json; unlocks may carry `belt_nodes`): splitting, smart_logic, electrification, clean_power (solar + nitrogen pair), nuclear. Defs.validate checks belt_nodes ids, power_use>=0, gen>0, pole range>=3, fuel/fuels.json links.
- balance.json keys `logistics2`, `power` (unpowered 0.5, min 0.2, chip 10, bucket 0.05, ledger source power_waste); `map.extra_share`.

## Deviations (review)
1. splitting and electrification are tier 2, not T1: T1 techs are free at start and enter `research.done`, which changes every golden hash.
2. Coal on the start map: generator pass `_convert_extra_nodes` (own RNG, tiles identical, only node_res changes) is implemented and tested, but `map.extra_share` ships at 0.0: 0.35 broke goldens (miners hit coal cells). Orchestrator: flip to 0.35 together with a golden regen.
3. Plan says 1 solar covers 25% of a smelter; with smelter power_use 40 it covers 62.5% (25/40). Kept the plan's consumer numbers.
4. view/building_3d.gd FLAT_FALLBACK got the 6 new ids (region L5) to keep test_building_3d green; L4 should drop them when voxel models land (model keys must use the new ids, not essence_burner).
5. QA bot: `QaBot.l2_step` + bot_report profile "power" (splitter -> 2 smelters -> merger into storage_in, pole line, coal gen hand-fed). It probes hooks via has_method/get, so it is a no-op until L1/L2/L3 merge; the "after" column equals "before" today.

## power_model (tools/power_model.gd; 3-smelter line, per day)
| mix | f | thr off/on | ratio | waste off/on |
|---|---|---|---|---|
| 1 coal | 0.83 | 11.2/18.8 | 1.67 | 11.2/24.8 (x2.20) |
| 2 coal | 1.00 | 11.2/22.5 | 2.00 | 11.2/34.5 (x3.07) |
| 1 nitrogen | 1.00 | 11.2/22.5 | 2.00 | 11.2/24.5 (x2.18) |
| 1 reactor | 1.00 | 11.2/22.5 | 2.00 | 11.2/23.0 (x2.04), 0.5 spent_fuel/day |
| 4 solar | 0.83 | 11.2/18.8 | 1.67 | 11.2/18.8 (x1.67) |

Gates met: ratio 1.67 in 1.6..2.0, waste x2.2 >= 1.3, 4 solars cost 192 vs coal gen 25 essence (>= 2x). Waste per kE: coal 1.0, nitrogen 0.139, uranium 0.010.

## Bot table, 25 d x 5 seeds (automation == power profile until L3 merges)
s1 alive w6 refined 30 pol 4 | s2 alive w7 255 pol 87 | s3 planet_dead d22 w6 276 pol 100 | s4 colonists_dead d22 w6 180 pol 65 | s5 alive w7 192 pol 76. Supply/demand and brownout % columns need L3.
Tests: tests/test_logistics2_defs.gd (10), tests/test_qa_l2.gd (2), sim_contract row for fuels.json.
