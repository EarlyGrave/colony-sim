# OPT-W2d report: enemy hot loop (#4) + belt cache version + pick memo

Files: `sim/threats/enemy.gd`, `threat_system.gd`, `threat_model.gd`, `sim/logistics/belt_grid.gd` (`version`), `tests/test_threat_scale.gd`,
`tools/perf_threat_belts.gd` (`--nocol=1`, on-CPU `cpu_avg` from /proc, since the box is shared and wall time is noisy).

- Belt caches (pick memo, `_best_static` memo, `_best_belt` memo) now key on `BeltGrid.version` (bumped on place, remove, direction change; not on
  belt_count). Tests: version bumps on place/rotate/remove; remove+replace at equal count between two picks equals the brute-force pick.
- Enemy hot loop: `has_meta("tg")`/`get_meta("bite_cd")` and per-tick `e.def.get`/balance dictionary lookups replaced by typed Enemy fields
  (`winding`, `bite_at`, `structure_dmg`, `cd_ticks`); meta "tg" is still written (qa bot / state). `_attack_structure` reads belt arrays
  directly and is skipped when no belts; building range test memoised per (cell, target); `Enemy.move_flow` skips the always-zero
  `_bonus_steps/move_gain` chain; retarget period cached. New ThreatSystem scalars live in an inner `Hot` object (the golden dump lists
  script variables of ThreatSystem, so plain vars would change it). Not done: full SoA / get_by_id index (colonist and building lookups
  only run on retarget; Enemy objects kept as the API). Enemy state stays on objects: a real SoA needs the view + tests migrated (W2 follow-up).
- pick() memo (outcome-neutral): per enemy, only fixed points (result == current sticky target) are kept, valid while candidates, belt version, cell and
  target are unchanged and no live colonist can beat the stored score (cheap bound, exact re-score otherwise); off while ability flags are live.
  Candidate generation only bumps when a refresh produces different ids/values/geometry. 87% of retargets while chewing belts are memo hits.
- Results (600 ticks, 250 map, 300 crawlers; hashes identical to W1a: 2907637144 / 2862296185):
  belts 8.2k: threats avg 11.8 -> 5.7-5.8 ms (cpu 10.5 -> 5.9); no belts bench 4.15 -> 3.9 (cpu 4.3 -> 4.0); `perf_threat.gd` 3.6 -> 3.0 ms.
- Acceptance: belts <= 6 ms MET; no-belts <= 2.5 ms NOT met (3.0). ~1.1-1.4 ms/tick of the remaining cost is `Pathfinder.advance_flows`
  (`FlowField.expand`, 8-neighbour BFS of 62k-cell fields, 6000 cells/tick) = W1c territory; speeding that up or lowering the budget changes timing, so not touched.
- Verification: `tests/golden` unchanged (`git diff --exit-code tests/golden` clean), `run_tests_sharded.sh` 601 passed / 0 failed twice, `--filter=test_perf_budget` 2 passed.
