# W1e report: perf contract + test sharding
- `Simulation.step()` has `profiling`/`profile` (per-system microsecond laps; one bool check per system when off). No state touched, goldens unchanged.
- `tools/perf_scenario.gd` (shared): 250 map, 12 colonists, 300 harmless enemies (damage_mult 0, colonists stay alive), optional `--belts=N`. `tools/perf_bench.gd` now times the real `step()`.
- `tests/test_perf_budget.gd` + `tests/perf_budget.json`: median of 3 x 300 ticks (after 100 warm-up), cap = budget x 1.5, plus 8k-belt logistics and first-tick/flow_builds. `PERF_SKIP=1` skips; a `waived` map exists for unmet budgets (currently empty).
- Wall-clock asserts in test_biomes / test_campaign use `TestCase.perf_skip()` (PERF_SKIP / PERF_SKIP_WALL); the sharded script sets PERF_SKIP_WALL=1, CI runs the budget test single-process afterwards.
- Sharding: `runner -- --shard=i/n` (greedy longest-first by `tests/shard_weights.json`), `tools/run_tests_sharded.sh [n]`; CI and CLAUDE.md updated.
- Research, campaign and autopilot are not part of `Simulation.step()`, so they have no lap.

Suite wall time: before 372 s single -> after 129 s sharded x4 (2m09, twice); single process 336 s, 596 passed, 0 failed.
Shared fixtures for the long bot tests were NOT done: shards already beat the target; the longest single test is ~50 s.

| system (ms/tick, 250 map, 300 enemies, 12 col) | avg | p95 | budget avg/p95 |
|---|---|---|---|
| threats | 2.171 | 3.311 | 2.0 / 5 |
| colonists (+jobs) | 0.297 | 1.128 | 0.5 / 1.5 |
| logistics (no belts) | 0.005 | 0.007 | 0.5 / 1.0 |
| contamination | 0.027 | 0.044 | 0.5 / 2 |
| mutation | 0.011 | 0.041 | 0.5 / 2 |
| total | 2.642 | 3.913 | 4 / 10 |

First tick 19.8 ms, flow_builds 26/600. With 8k belts + 300 enemies the bench shows threats ~100 ms avg and 1028 flow builds (belt targeting): the W1a/W1c target; the test only enforces logistics at 8k belts.
