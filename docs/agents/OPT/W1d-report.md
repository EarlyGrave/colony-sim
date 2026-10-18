# W1d report (jobs cache, item counters)
- Baseline (188a484) on tools/w1d_probe.gd (250x250, 8 colonists, standard colony + farm + bench + chain, 3000 ticks, no enemies):
  colonists.tick 0.55-0.76 ms/tick; after: 0.29-0.36 ms/tick (~2x, noisy machine).
- Profile showed deliver_materials giver = 0.37 of 0.55 ms (bp_stand pathing + full stacks scan per blueprint item). Mine index cache already existed (1504b01).
- deliver_materials_giver.gd: one stored-stack index per find() (stacks order kept), bp_stand only evaluated when storage holds a needed item (pure fn, same result).
- item_system.gd: incremental ground counts in add_at/take_at; count_stored lazily rebuilt, invalidated by zone_changed/zone_settings_changed, then updated incrementally. count_on_ground/count_stored now O(1).
- Not done: int-key reservations, assign staggering, haul_giver stack-scan cache (haul 0.02 ms/tick, not hot at 8 colonists); bus batching skipped: item_mined consumers are sim systems (tutorial, threats) needing per-event semantics, view batching belongs to the view workers.
- Remaining giver cost is mostly Pathfinder._ensure_components rebuild charged to the first reachable() caller (not my files).
- Tests: tests/test_job_sequence.gd records job start sequence (3000 ticks, seeds 1,2; sha256 identical before/after) + counter brute-force check. Full suite 596 passed, 0 failed, twice. `git diff tests/golden` empty.
