# A1c report - belts core
Files: sim/logistics/belt_grid.gd (BeltGrid), sim/logistics/logistics_system.gd (LogisticsSystem), tests/test_belts.gd.
Shared (region A1c): simulation.gd (logistics var, construction, logistics.tick() after colonists), data/balance.json automation.belt_ticks_per_cell=5 (2 cells/s).
Tests: 7 new; full suite 348 pass.
Model: dense arrays (dir 0N 1E 2S 3W/255 none, item id, progress); one item per cell; arrival at end of N belts = exactly N*tpc ticks, then 'ready'.
Stalls: jammed items wait, no loss; cycles stall (legal); head-on belts never exchange; merges: lowest cell index wins.
Counters: inserted == extracted + destroyed + item_count (removing a loaded belt counts as destroyed).
API for A1d: sim.logistics.can_place_belt(cell) (in bounds + map passable; add a building check if buildings do not block passability), place_belt_cell(cell,dir), remove_belt_cell(cell), belt_dir(cell), state_hash() (A1d should add it to save_game state_hash; not included yet).
API for ports (A2b): insert_item(cell,name), take_ready_item(cell)->String, belts.peek_ready/take_ready.
Reserved: level param (must be 0).
Perf: step() scans width*height when any item is on belts (early-out when empty); dirty lists later if 250x250 needs it.
