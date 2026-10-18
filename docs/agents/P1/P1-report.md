# P1 report: benchmark + map-size option

Done
- Start opts `map_w` / `map_h` (default: balance `map.width/height` = 64) read in `Simulation.start_new_game`
  (`# region P1`); rock/deposit cluster counts scale with area when the size differs (identical at 64).
  Documented in `sim/meta/start_opts.gd`. No other hard-coded 64 found in sim/view (only UI button sizes, shader uniforms
  use the real map size). Pathfinder/camera take size from the map.
- `tools/perf_bench.gd/.tscn`: `-- --size= --enemies= --ticks= --seed= --view=0|1`. Mirrors `Simulation.step()` order and
  times each part. Enemies are placed on random reachable ground via `sim.rng` and `threats._spawn`; the wave is held
  "active" so they are not culled. `--view=1` runs `view/game.tscn` at 3x and prints ms/frame (needs a display; NOT
  tried here, no xvfb run).
- `tests/test_perf_bench.gd`: size option, default unchanged, bench subprocess (`--ticks=20 --size=96 --enemies=20`).

Not done
- jobs and combat are not separate lines: they run inside `colonists.tick` / `threats.tick` (printed as "included").
- `--view=1` unverified. No change to balance.json (map key already existed).

Baseline (600 ticks, seed 1, headless, noisy: other workers running in parallel). ms/tick avg / p95
| case | colonists | threats | contamination | mutation | total |
|---|---|---|---|---|---|
| 64, 0 enemies | 0.20 / 0.89 | 0.00 / 0.01 | 0.01 / 0.02 | 0.09 / 1.50 | 0.33 / 1.66 |
| 64, 300 enemies | 0.05 / 0.36 | 0.96 / 1.99 | 0.01 / 0.03 | 0.08 / 1.43 | 1.12 / 2.56 |
| 250, 0 enemies | 2.12 / 15.2 | 0.01 / 0.01 | 0.02 / 0.03 | 1.66 / 24.2 | 3.85 / 24.4 |
| 250, 300 enemies | 0.30 / 0.42 | 1.38 / 2.50 | 0.02 / 0.03 | 1.32 / 23.5 | 3.04 / 24.6 |
Caveat: with 300 enemies all colonists die early, so colonists numbers there are not meaningful; sim keeps ticking in the bench.
Map generation: 64 ~25 ms, 250 ~270-470 ms. Main 250 hotspots: mutation p95 ~24 ms spikes (P2), colonists p95 15 ms with 4 colonists (job scans, P5).

Tests: full suite 324 passed, 0 failed (165 s).
