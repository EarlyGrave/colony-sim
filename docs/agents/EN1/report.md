# EN1 report (W1: path helper + PoNR + dirty fuel)
- sim/endings/ending_system.gd (EndingSystem, state in QuestLog flags so save/hash work): path(), set_path(id), is_locked(), petition_allowed(), tech_ok(), mark_won().
- Simulation (region EN1): `sim.path()`, `set_path(id)` and `ending_won(id)` (recorded; bus signal `ending_won(id)`); deliver_petition refuses when a non-submit path is locked. No path = old behaviour.
- PoNR: submit = petition phase 1 done; fight/escape/remission = quest flags ponr_<id> (data/endings.json). set_path refused once locked.
- C1: recipe fuel_cell_dirty (ore 6 + refined 1 -> fuel_cell 1 + waste 3, pollutes:true, requires_tech bulk_refining, stations refinery+smelter); bulk_refining lists it.
- Deviation: refinery has one fixed recipe, so the multi-recipe station that actually runs it is the smelter; gated recipes are only accepted/run after the tech (Building.gated_recipes/gated_ok), which keeps goldens identical.
- Tests: test_endings_path (5), test_dirty_fuel (3). run_tests_quick: 14 passed, 0 failed (golden replays unchanged). Contract doc rows added; test_qa_commands allow-list gets "path".
