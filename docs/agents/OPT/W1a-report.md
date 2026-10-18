# OPT-W1a report: threat targeting cache (#1; #11 not done)

Files: `sim/threats/threat_model.gd` (cache, `# region W1a`), `tests/test_threat_scale.gd` (brute-force equivalence test),
`tools/perf_threat_belts.gd` (bench). `sim/map/spatial_hash.gd` untouched (see below).

Bench: `godot --headless --path . -s tools/perf_threat_belts.gd -- --belts=1|0 --n=300 --size=250 --ticks=600`
(8228 belt cells via `Simulation.place_belt`, 300 crawlers, 6 beds + refinery + 3 turrets + 4 colonists; times `ThreatSystem.tick()` only).
Cloud box was shared and noisy (load avg ~2.8), so treat +-20% as noise.

| scenario (600 ticks)  | before avg / p95 / max (ms) | after avg / p95 / max (ms) | state hash |
|---|---|---|---|
| 250 map, 300 enemies, 8.2k belts | 297.4 / 427.6 / 635.9 | 11.8 / 18.4 / 171.0 | identical (2907637144) |
| 250 map, 300 enemies, no belts   | 3.78 / 7.33 / 86.8    | 3.57 / 6.27 / 81.1  | identical (2862296185) |

What changed in `pick()` (results identical, same tie-breaks: strict `>`, lowest candidate index wins):
- candidate -> index map, so the sticky current target is looked up (and scored lazily) instead of found by a full scan;
- belt candidates (one per 8x8 region) are found by a ring walk over the region grid with an exact upper bound
  (value*bias/(1+(dmin/d0)^2), dmin from the ring geometry) instead of scoring all ~600; ties between belts resolved by index;
- per-species bias arrays + candidates sorted by upper bound (early exit), integer distances via a float32 sqrt table
  (bit-identical to `Vector2.distance_to`), per-(species, cell) memo of the best static candidate (buildings+belts) for one
  refresh epoch, validated on every hit by re-scoring the remembered winner (static scores only ever drop);
  the memo is dropped when `belt_count` changes. Colonists stay live (ability flags can raise a score, so no pruning while any flag exists).

Verification: `test_golden` byte-identical (tests/golden clean in `git status`), full suite 595 passed / 0 failed twice
(331 s, 336 s). New `test_pick_matches_brute_force_with_belts_and_destruction` compares against the old full scan.

Status vs acceptance (<= 4 ms with belts, <= 1.5 ms without): NOT met. With belts 297 -> 11.8 ms (25x), but pick() is still
~25 us per call and 200+ retargets/tick happen while enemies chew belts (~5 ms/tick). The no-belt case is dominated by code
outside this task's files: flow-field builds and the per-enemy loop in `threat_system.gd` (W1c / W2d); pick() is only ~0.5 ms there.
Residual risk: the belt memo is keyed on `belt_count`, so a remove+place of the same cell between two picks (net count unchanged)
could revive a stale candidate one epoch late.

#11 SpatialHash: not changed. Packed buckets that keep query order (bucket-major, insertion) need order-preserving erase, which keeps
the O(bucket) cost; the gain (~15% of the non-pick part) was not worth the golden risk in this pass.
