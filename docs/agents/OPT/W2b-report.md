# OPT-W2b report: unit MultiMesh + shader animation (#6)

Files: new `view/unit_layer.gd` (one MultiMesh per sheet texture + per-group blob-shadow MultiMesh; billboard, frame pick and walk
cycle in the shader), `view/world_3d.gd` (`# region W2b`; plus minimal hooks outside it: removed `_units/_facing` vars and the
Sprite3D unit funcs, `_w2b_*` call lines, and the G1c shadow loop replaced by a comment since shadows now come from UnitLayer),
`tools/view_bench.gd` (fixed for campaign-based `new_game`, added `--shot=`). No sim changes.
Instance data: origin x/z in the transform slot, custom = (facing row, moving, phase); tint is a per-sheet uniform; hop of
single-sprite creatures and the 1x1 "left = mirror" case live in the shader. Culling: view_rect + CULL_MARGIN kept, culled units are
not pushed. Carried items stay Sprite3D (only for carrying colonists); hp bars, drafted markers, selection ring untouched.
Positions: still `visual_pos()` (already lerped by move_t); no extra sub-tick smoothing was added.

Numbers (250 map, 300 creatures, xvfb software GL, box load avg 15-20 so +-25% noise; `tools/view_bench.tscn`):
- `world3d._process` script ms: before 2.1-3.7 (zoom 1), 12.4 (zoom 2); after 0.58-0.9 (zoom 1), 1.07 (zoom 2).
  Unit part ~2.5 ms -> ~0.45 ms (about 0.15 ms of `_process` is non-unit work): meets <= 0.5 ms.
- frame ms zoom 1: before 168/175/194, after 152-166; zoom 2: before 162, after 137. About -10..-15%, NOT the -30% target:
  the software-GL frame is dominated by the ground chunk viewports redrawn every frame (W2a), not by unit draws.
Screenshots (default zoom / zoom 2) in scratchpad: before_z1.png, after_z1.png, before_z2.png, after_z2.png. Visually equivalent
(only walk-frame phase and overlap order differ). Tests: `run_tests_sharded.sh` 599 passed, 0 failed twice; goldens untouched.
