# K4 report (tech debt: flow BFS + splitter->merger fairness)

## Flow BFS (sim/map/flow_field.gd, expand())
- Detached dist/queue to locals (no member access / COW in the hot loop), precomputed neighbour offsets,
  interior cells take an unrolled path (no bounds checks; diagonals reuse the 4 orthogonal walk flags),
  border cells use the generic loop. Visiting order unchanged -> queue and dist byte-identical.
- Micro bench (250x250, 6000 walls, 2 sources, in-process old vs new class, identical dist asserted):
  full build 195-204 ms -> 79-90 ms (2.3x). Instrumented expand share in the threats bench: ~1.23 -> ~0.70 ms/tick.
- tools/perf_threat.gd --n=300 --size=250 (threats avg ms/tick, best-of-8): before ~3.0-3.2, after 2.75-3.1.
  The box was under heavy load from other workers (load avg 13-15), so the 2.5 ms goal could NOT be confirmed;
  expected ~2.6-2.8 unloaded. tests/perf_budget.json left unchanged (measure on a quiet machine first).
- Test: tests/test_k4_perf.gd (flow == reference BFS: unbounded, incremental expand(37), bounded radius).

## Splitter -> merger fairness (sim/logistics/belt_grid.gd, region K4)
- Bug: a splitter feeding a merger side input was a non-contender and claimed the merger unconditionally,
  starving the belt input (repro: splitter=129 belt=0 over 400 ticks).
- Fix: a splitter whose only valid output is the merger now contends in the rotation (_splitter_only_feeds),
  and _node_pick uses _out_ok() = _out_free && (merger -> _merger_allows). Splitters with several outputs keep
  the old non-contender behaviour (avoids stalls when they route elsewhere).
- Test: tests/test_splitters.gd test_splitter_to_merger_fair (region K4), 50/50 within max(2, 2%).
- Goldens unchanged (no regen), so no `k4_merger_fair` flag was needed.

## Suite
tools/run_tests_sharded.sh 4: TOTAL 703 passed, 0 failed (includes goldens, byte-identical).
