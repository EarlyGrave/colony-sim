# A1d report: belt commands + save version
- Simulation region A1d: place_belt(cells: Array, last_dir:int) -> bool (atomic; 4-connected, passable, no building/blueprint, no dup cells; belt i points to cell i+1, last uses last_dir; dir 0=E,1=S,2=W,3=N), remove_belt(cells) -> bool, set_belt_dir(cell, dir) -> bool, can_belt_cell_error(c). All call _record; a 30-cell drag = 1 log entry.
- SaveGame: VERSION 2 (old -> error "version" = incompatible; game.gd shows English "Old save is incompatible with this version."); Array-of-Vector2i args encoded as {"a":[[x,y]..]}; state_hash includes logistics.state_parts().
- Stub: sim/logistics/logistics_stub.gd (LogisticsStub, REPLACE with A1c). Simulation has `var logistics` (untyped), set in _init_systems only if null (one line; A1c should assign LogisticsSystem before/instead).
- Methods called on sim.logistics (A1c must provide): place_path(cells: Array, dirs: Array[int]); remove_at(cell) -> bool; set_dir(cell, dir) -> bool; has_belt(cell), dir_at(cell) -> int (-1 none) [tests]; state_parts() -> Array deterministic snapshot for state_hash.
- Tests: tests/test_belt_commands.gd (4). Full suite: 345 pass, 0 fail.
