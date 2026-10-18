# G1b report: buildings in 3D
Done: new `Building3D` (view/building_3d.gd) renders hq, refinery, workbench, turret, door, stove, bed as raised
blocks (per-building shader: side shading, damage tint, broken = dark) with the existing top-down art laid on the
top face. Footprint = sim footprint. Turret = block + flat barrel sprite rotated by WorldView turret aim
(`WorldView.turret_aim(id)`). Door lowers to a slab when a colonist/enemy is within 1.3 cells (visual only; sim has
no door state). WorldView skips ground art for 3D kinds when `flat`; wall and training_dummy stay flat (listed in
`Building3D.FLAT_FALLBACK`). Blueprints untouched.
Not done: front-view `b3_*.png` sprites (optional, skipped); refinery ground smoke no longer drawn for 3D kinds
(broken smoke, HP/condition/progress bars still are).
Files: view/building_3d.gd, view/world_3d.gd (region G1b), view/world_view.gd (region G1b), view/game.gd (1 line),
tests/test_building_3d.gd.
Tests: test_building_3d::{test_every_building_has_3d_or_flat_fallback, test_footprint_transform_matches_sim,
test_barrel_angle}. Full suite: 309 passed, 0 failed.
Screenshot: /tmp/claude-0/-home-user-colony-sim/2c9ef3d5-c73d-4d98-a862-7d15a0bb0a1a/scratchpad/g1b.png (capsule block visible).
Known issues: only the capsule is in the default screenshot scene, so turret/door/stove/bed visuals and barrel
orientation are not visually verified. Tall blocks may hide units directly behind them from the tilted camera.
