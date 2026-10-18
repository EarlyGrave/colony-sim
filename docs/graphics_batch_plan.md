# Graphics batch G1 "Polished pseudo-3D" — plan (from prompter)
One wave, 4 parallel Sonnet workers (G1a..G1d). Cheap: short reports, no exploratory essays.
## Common rules
- Start with `git reset --hard claude/colony-sim-godot-4jftsm`. Work in your worktree, commit there, NEVER push.
- `sim/` untouched; view reads sim only. No randomness from `randi()/randf()`/Time in anything sim-visible
  (cosmetic RNG in view is fine, local `RandomNumberGenerator` with fixed seed per entity id).
- Art comes from `tools/gen_art.py`: add a function in your own `# region <agent>` block and call it from `main()`
  (one-line call inside the region marker). Commit generated PNGs + .import files. Pixel art, nearest filter.
- Shared files (`view/world_3d.gd`, `tools/gen_art.py`) only edited inside `# region <agent>` blocks; keep hooks
  in existing functions to one line calling your region's function.
- Run `godot --headless --path . --import` first after adding any `class_name`; then ALL tests must pass:
  `godot --headless --path . res://tests/run_tests.tscn`.
- Screenshot check (attach path in report): `xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn -- --out=<scratch>/g1x.png`; open it and confirm visually; note defects honestly.
- Report <= 30 lines in `docs/agents/<agent>/G1-report.md`: done / not done / files / test names / known issues.
## G1a creatures: 4-direction sheets
- Goal: crawler, spitter, brute, burrower get 3x4 walk sheets (same layout as colonist `*_sheet.png`), used by
  `_update_enemy` with the same facing logic as colonists (reuse `_face`).
- Owns: new `view/creature_sheets.gd` (frame table, sheet loading), `# region G1a` in `tools/gen_art.py`
  (`<type>_sheet.png`), `# region G1a` in world_3d.gd `_update_enemy`.
- Accept: each type has distinct silhouette per direction; walking cycles frames; idle when still; fallback to old
  single sprite if sheet is missing.
- Tests `tests/test_creature_sheets.gd`: every enemy type in `data/enemies.json` has a sheet file and a frame
  entry; frame rect for (row, col) is inside the texture; facing function maps dx/dy to the right row.
## G1b buildings in 3D
- Goal: capsule, refinery, turret (base + rotating barrel Sprite3D following WorldView `_turret_aim`), stove, bed,
  workbench, door rendered as raised blocks / standing sprites instead of flat top-down art; flat art removed
  from the ground layer for those buildings only.
- Owns: new `view/building_3d.gd` (class `Building3D`, node child of WorldView3D), `# region G1b` in world_3d.gd
  (create/update call, one line each) and in world_view.gd `_draw_buildings` (skip drawn kinds), `# region G1b`
  in gen_art.py (front-view sprites `b3_<id>.png`, optional).
- Accept: footprint (2x2 etc.) matches the sim; broken/damaged state visibly different (darker tint); door
  open/closed state; blocks do not hide colonists standing behind (depth/ordering ok); blueprints stay flat.
- Tests `tests/test_building_3d.gd`: every building in `data/buildings.json` has a 3D representation or an
  explicit flat-fallback entry; footprint-to-transform helper returns centre/size equal to sim footprint;
  barrel angle helper returns expected angle for a target.
## G1c atmosphere and polish
- Goal: sky gradient background (WorldEnvironment/ProceduralSky or shader quad, no new textures needed), distance
  fog + soft darkening/fade at map edges (map border does not end in a hard line), subtle day tint kept
  (`_update_tint`), ground-contact blob shadows under units, selection marker (ring under the selected colonist),
  item piles standing (ore/refined/waste as small upright Sprite3D or low blocks, visible from the camera).
- Owns: new `view/atmosphere.gd` (class `Atmosphere`), `view/selection_marker.gd`, `# region G1c` in world_3d.gd
  (setup, shadows, item piles), `# region G1c` in gen_art.py (shadow blob, ring, pile sprites).
- Accept: no hard map edge in a screenshot at default zoom and at max zoom-out; fog off switch via constant;
  FPS cost small (shadows via one MultiMesh or per-unit quad, items capped e.g. 300 visible).
- Tests `tests/test_atmosphere.gd`: Atmosphere builds without errors under headless; fog/fade parameters sane
  (start < end); selection marker follows a colonist position and hides when selection cleared.
## G1d camera, effects, depth
- Goal: camera polish (smooth pan inertia, zoom limits and tilt clamps verified, pan clamped to the map plus
  margin), particles/shots in 3D (turret tracers, hit sparks, enemy spit projectiles, death puffs, mining dust)
  reading the EventBus signals only, correct sprite depth sorting (billboards of units in front of/behind
  blocks, no z-fighting between ground overlays and ground plane).
- Owns: `view/camera_controller.gd`, new `view/effects_3d.gd` (class `Effects3D`), `# region G1d` in world_3d.gd
  (spawn node, one line), existing `tests/` camera test if any.
- Accept: zoom limits hold under many wheel steps; pan never leaves bounds; effects freed after lifetime (no
  node leak after 5 s sim time); no effect code runs in sim.
- Tests `tests/test_camera_3d.gd`: `screen_to_world` then project back (`cell_to_screen`) round trip within 0.05
  cell for 5 screen points and 3 zoom levels; zoom clamps at min/max; pan clamp. `tests/test_effects_3d.gd`:
  effect spawn count per event, all freed after lifetime.
one screenshot at default zoom, update PROGRESS.md Session 4 "Not yet" line.
Merge order G1a, G1b, G1d, G1c; conflicts only inside world_3d.gd regions; then full tests + one screenshot.
