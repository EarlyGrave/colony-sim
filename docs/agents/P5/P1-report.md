# P5 report: jobs scan caching
Result: NOT implemented on purpose; profiling shows job scans are not a real cost at default size.
- Probe: tools/job_probe.gd (standard_colony, 8 colonists, seed 1, 3000 ticks, assign() sampled every 5 ticks for idle colonists).
- Before (64x64): whole Simulation.step() 0.366 ms/tick avg; JobSystem.assign() 0.373 ms/call, 173 sampled calls,
  upper bound ~0.11 ms/tick for jobs. Target (<= 1 ms/tick) already met at 64.
- Idle colonists already stagger searches via balance colonist.idle_retry_ticks (10).
- 250x250 not measurable: tools/perf_bench.gd (P1) not merged here. Mine/haul givers are O(map cells)/O(stacks) per call;
  if the P1 bench shows jobs > 1 ms at 250, add cached candidate lists (mine_designated, items.stacks) with version counters.
  Skipped now to avoid risk to assignment-order determinism.
- Files: tools/job_probe.gd, this report. No sim changes; tests not re-run (no sim code touched).
