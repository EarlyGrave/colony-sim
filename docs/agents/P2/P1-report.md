# P2 report: contamination + mutation fields (batch P1)
Bench: headless, 250x250 empty map, 40 waste piles, level 40, 800 ticks, sim only (no creatures). Desktop ms/tick.
| | before (one-shot) | after (sliced) |
|---|---|---|
| mutation avg / p95 / max | 1.77 / 27.5 / 49.3 | 1.03 / 1.64 / 2.02 |
| contamination.tick avg | 0.075 | 0.06 |
| dense field (every cell > 0), mutation avg / p95 | n/a | 1.86 / 3.1 (contamination 0.11) |
| overlay ms/frame (p50 / p95) | 62500 draw_rect per frame | 0.70 / 1.0 (1 draw call) |
## Done
- MutationSystem: if cells > `balance.field_perf.slice_cells` (4096; 64x64 = 1 slice, so default maps run the unchanged one-shot path, identical results) the
  update is split into row bands, one band per tick over the first `slices` ticks of each `update_ticks` window; double buffer swap at cycle end.
- Sparse skipping: per-row activity flags; bands whose neighbourhood is all zero are skipped (values below `field_perf.zero_eps` snap to 0).
- Normalisation is linear: scale from the running sum, applied inside the next cycle's diffusion (no extra pass). Mutation detection runs inside the band loop.
- Edits during a cycle (`add_at`, purify, scrub, sources) go through `_bump`, which also patches the half-built buffer so swaps do not lose them.
- Overlay: one map-sized ImageTexture (`update_field_texture`, region mutation in world_view.gd), per-row dirty flags from the sim, at most
  `field_perf.overlay_rows_per_frame` (12) dirty rows recoloured per frame, only changed 8-bit pixels rewritten, one `draw_texture_rect`.
## Not done / notes
- Dense worst case (whole map covered) is 1.9 ms avg, above the 1.5 target; realistic sparse fields 1.0. p95 under 4 ms in both.
- Overlay can lag up to ~21 frames for a full-map change. ContaminationSystem.waste_units still scans stacks each tick (0.06 ms at 40 piles).
- A cycle now takes `slices` ticks, so values lag by under one update window on big maps.
## Files
sim/mutation/mutation_system.gd (region P2), view/world_view.gd, data/balance.json (`field_perf`), tests/test_field_perf.gd.
## Tests
5 new (no slicing at 64, identical field hash for two 250x250 500-tick runs, sliced vs full converge, overlay size/colour/row budget, edit survives swap). Full suite green.
