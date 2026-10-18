# T4 report: AI chip operator

Done: item `ai_chip`, recipe `make_ai_chip` (assembler, 4 refined_essence + 2 parts), tech `ai_chips` (tier 3, separate block at the end of data/research.json),
`data/chips.json` (all numbers), `sim/automation/chip_system.gd` (`sim.chips`), `CalibrateJob`/`CalibrateGiver` (work type "operating", needs operating >= 1),
commands `install_chip(building_id)` / `remove_chip(building_id)` (recorded), `chip_slots: 1` only on research_bench, smelter, assembler (miners refused).
Behavior: bench = bench_rate x 0.8 with no colonist (ResearchOperator.speed has a chip branch, ResearchGiver skips chip benches); smelter/assembler run 4 of 5 steps;
waste x1.3 (sim.rng roll only with a chip); 1 refined essence upkeep at each day start (retried while unpaid, unpaid = stopped); calibration every 3 days, then stopped until a colonist calibrates (60 ticks);
broken/destroyed building drops the chip. Inspector line + 64 px install/remove button in `# region T4` of building_section.gd.
T1 hook: `sim.chips.threat_mult(building)` (2.0 while busy, else 1.0) and `sim.chips.colony_threat_mult()`. No T1 API existed on this base, so nothing in threat code was touched.
Shared edits (all `# region T4`): simulation.gd, defs.gd, building.gd, building_system.gd (waste, processor steps, tech-gated recipe, spill), operator.gd, research_giver.gd, giver_registry.gd.
Also edited: data/work.json (calibrate giver under "operating"), data/zones.json (stockpile accepts ai_chip), docs/sim_contract.md (commands, tick 7b, chips.json, section 10).
Tests: full suite 434 passed + test_research count fix (15 techs, tier 3 = 4) re-run green. Goldens NOT regenerated (test_golden passes).
Goldens: unchanged, still green. Chip state is not in state_hash (rebuilt by command replay).
Notes: a chipped smelter/assembler is slower (x0.8) and dirtier (x1.3) than an unchipped one that already runs without an operator, as specified; the benefit is only the
bench (no colonist). Calibration timing is walk time + 60 ticks (test allows +40). Assembler now accepts refined_essence/parts as inputs because of the chip recipe.
