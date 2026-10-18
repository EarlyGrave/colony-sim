# W2a report - ground redraw on dirty only (#7)
Files: view/world_view.gd (region W2a), view/chunk_layer.gd (region W2a), tools/w2a_bench.* and tools/w2a_cmp.* (probes).
- WorldView (flat) no longer redraws every frame: 3 canvas items per chunk (under: zones/field/designations/plants; over: buildings,
  blueprints, shots, particles, wave arrow, patrol/belt/selection; night tint). A canvas redraws only when dirty: bus signals
  (tile/zone/designation/plant), per-tick polling of buildings/blueprints (5 ticks for plants), field-overlay rows actually rewritten,
  selection/patrol/belt-draft signature, night alpha (8-bit steps), contamination modulate. Animated chunks (pulsing designation,
  refinery/broken smoke, shots, particles, wave arrow) redraw per frame only while they hold such content. Off-screen chunks stay pending.
- ChunkLayer viewports are UPDATE_ONCE per dirty on-screen chunk (was UPDATE_ALWAYS for every active chunk); found via a World2D registry.
- Unit shadows/units were already in WorldView3D; enemy last-position / turret aim bookkeeping moved out of _draw into per-tick polling.
Numbers (xvfb opengl3, llvmpipe, machine under load ~10-20, interleaved A/B, tools/w2a_bench.tscn):
- 64/0:    base 100-105 ms -> 70-73 ms/frame (-30%); steady-state chunk viewport renders 0/frame, redraws 0.
- 250/300: base 409 ms -> 262 ms/frame (-36%); 5 chunk refreshes in 40 frames.
- Root viewport (3D + HUD on llvmpipe) is 65 ms (64/0) / 257 ms (250/300) and is untouched; the chunk-viewport share is now 0, so
  -50% of the total is not reachable inside W2a files (needs W2b units MultiMesh etc.).
Visual: /tmp/claude-0/-home-user-colony-sim/2c9ef3d5-c73d-4d98-a862-7d15a0bb0a1a/scratchpad/{before_cmp,after_cmp}.png (zone, blueprints, field overlay,
patrol, selection, night): 75 differing pixels in a 38x2 box (zone edge line at a chunk seam), otherwise identical; before.png/after.png = default start.
Tests: bash tools/run_tests_sharded.sh twice: 599 passed, 0 failed. No sim changes; tests/golden untouched.
