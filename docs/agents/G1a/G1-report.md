# G1a report: creature 4-direction sheets
Done:
- 3x4 walk sheets (idle/stepA/stepB x down/left/right/up) for crawler, spitter, brute, burrower, derived in
  `creature_sheets()` (`# region G1a` in tools/gen_art.py) from the existing front sprites: back view hides eyes,
  side view has a narrowed body with a forward-pushed head, steps bob legs/body.
- `view/creature_sheets.gd` (`CreatureSheets`): sheet path/loading (cached), frame index/rect, `row_for_delta`.
- `world_3d.gd`: `_update_enemy` uses `_face` row + WALK_CYCLE while moving, idle col 0 when still;
  falls back to old single sprite (flip_h) if the sheet is missing. Code in `# region G1a`.
Tests: tests/test_creature_sheets.gd (4 tests: sheet+frame per enemy in enemies.json, rects in texture,
  facing rows, missing-sheet fallback). Full suite: 310 passed, 0 failed.
Files: tools/gen_art.py, view/creature_sheets.gd, view/world_3d.gd, assets/sprites/*_sheet.png(+.import), tests.
Known issues:
- In-engine screenshot not taken (no xvfb run); checked the sheets as an upscaled PNG only.
- Side/back art is procedural from the front sprite, not hand-drawn; silhouettes are distinct but simple.
