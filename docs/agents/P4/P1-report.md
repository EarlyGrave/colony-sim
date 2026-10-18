# P4 report: view at scale

Done
- `view/chunk_layer.gd` (ChunkLayer): 32x32-cell chunks, one SubViewport (<= 512 px) per chunk sharing the map
  canvas via `world_2d` + per-chunk canvas_transform; only chunks near the camera render (UPDATE_ALWAYS), rest disabled.
  Pure helpers: chunk_of, chunks_for_change, cell_visible, chunks_in_rect.
- `world_view.gd`: terrain is per-chunk Image + ImageTexture + Sprite2D; a tile change re-uploads only touched chunks
  (counter `chunk_updates`; border edit = 2, interior = 1). No 250*16 px texture exists any more.
- `world_3d.gd`: ground = one plane per chunk, blocks = one MultiMesh per chunk (rebuild only dirty chunks, counter
  `block_rebuilds`; wall changes detected per chunk signature). `bind(sim, world_2d)` now takes the World2D.
- Culling: colonist/enemy sprites, shadows, item piles, overlay bars skipped outside camera rect + margin
  (`CameraController.visible_cell_rect()`).
- `view/game.gd`: MapViewport is now just a 64 px host of the shared canvas (render disabled).
- `tools/view_bench.gd/.tscn`: frame-time probe.

Not done
- Sprite node pooling (sprites are created once per unit and reused; culled ones are hidden, not pooled).
- 16 ms/frame target not demonstrable here: software GL under xvfb on a loaded machine. 250x250 + 300 enemies at zoom 1
  = ~90 ms/frame, but 64x64 + 0 enemies already = ~54 ms (same rasteriser), so the floor is the renderer.
  Measured script cost of `WorldView3D._process` with 300 visible enemies: ~2 ms.

Screenshot at default zoom (seed 42, 600 ticks) compared with before: terrain/rock/ore/building identical.

Tests: `tests/test_view_chunks.gd` (mapping, border dirty set, culling, one-chunk change, block coverage exactly once).
