# OPT-W1b sparse belts
- `BeltGrid.step()` now walks a sorted list of occupied indices (`_occ`, flagged by `_in_occ`) instead of all w*h cells; memo/claim are reset only where touched (no full-grid fill). Order = sorted indices, same as the old dense scan.
- `_resolve` returns early for empty/not-ready cells (stable result, no memo write).
- Bench: `godot --headless --path . -s tools/belt_bench.gd` (8000 belts, 600 ticks, step cost incl. inserts):

| items on belts | before ms/tick | after ms/tick |
|---|---|---|
| 4000 (jammed) | 2.8 | 1.1 |
| 2000 | 1.7 | 0.56 |
| 600 | 0.83 | 0.15 |

- Target <= 0.5 ms met up to ~1500 items on 8k belts; the 4000-item fully jammed worst case is 1.1 ms (GDScript per-item cost ~0.27 us), not 0.5.
- state_hash identical before/after for all three bench loads (1399289025 / 2101054657 / 2057843089); `git diff --exit-code tests/golden` clean.
- hp_dirty: keys are cell indices (bounded by w*h) and the view clears it each frame; not unbounded, left unchanged.
- Tests: two full runs, 593 passed; only failure both times is test_biomes::test_generation_time (wall-clock, machine loaded by parallel workers; passes alone 4/4). Not touched by this change.
