# W1c flow fields (#3, #13)
Files: sim/map/flow_field.gd, sim/map/pathfinder.gd, sim/mutation/mutation_system.gd.

- FlowField: bounded fields (chase, max_dist>=0) allocate `dist` only for the sources' bbox grown by max_dist
  (x0/y0/ww/wh); BFS is clipped to that window, which is exactly the reachable set, so distances are identical.
  Unbounded fields keep the full map.
- Pathfinder cache: partial invalidation (a walkability change drops only fields whose window contains the cell;
  `rebuild()` or >64 changes drops all) instead of clear-all on every `version` bump; LRU eviction (last_use stamp)
  instead of clearing all 48 at capacity. Fields stay deterministic functions of (sources, walk), so results are unchanged.
- Pathfinder components: flat byte-array flood fill with a preallocated queue; terrain-only labels are built lazily
  (only `reachable_terrain` needs them). Cuts the first-tick spike.
- MutationSystem one-shot (64x64): interior fast path in `_diffuse` (same summation order), `_detect_mutations`
  builds Vector2i only when a cell is >= threshold or `_mutated` is non-empty (same emission order).

Before -> after (this machine):
- perf_threat 300 enemies / 250: first tick 78 ms -> 31 ms (max), avg 3.54 -> 3.20 ms, steady p95 8.4 -> 6.4 ms.
- Full step() 250 / 300 enemies, belts placed at ticks 400 and 700 (scratch bench): max 7.3 -> 7.6 ms (budget 20),
  flow_builds in ticks 600-1200 = 0 before and after (budget 60); 19 builds total in warm-up.
- 64x64 mutation p95 1.46 -> 1.02 ms (tick total p95 1.53 -> 1.12 ms); results unchanged.
- tests/golden untouched; full suite 0 failed twice (see commit).
