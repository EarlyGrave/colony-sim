# PROGRESS.md

## Status (session 1)
- [x] E0 Skeleton: project, dirs, headless test runner, CI (tests + web export + Pages), README
- [x] E1 Map & camera: seeded generation (ground/rock/essence), pan/pinch/wheel camera
- [x] E2 Colonists & jobs: 3 colonists, AStarGrid2D, prioritized jobs with reservations, hauling
- [x] E3 Mining & stockpiles: designate deposits, stockpile zones, item ledger (conservation tests)
- [x] E4 Refining: refinery recipe from data/recipes.json, operator job, `first_refine_done`
- [x] E5 Waste & contamination: waste emission (less in dump), forecast with error bar in HUD
- [x] E6 Creature waves: strength from wave#, refined total, contamination; turrets; shelter + alarm
- [x] E7 Wear & repair: refinery/turret wear, breakdown stops them, repair job resumes
- [x] E8 Minimal HUD: resources, contamination, forecast, wave timer, speed, build tools, game over → new game

Tests: 45, all green (`godot --headless --path . res://tests/run_tests.tscn`, ~5 s).
Verified in headless Chromium (Playwright): a full game from start to colony
death played with touch taps only (seed 42: mining → dump → refinery → 3x →
turrets → capsule destroyed on wave 3).

## Next
- Merge to `main` so CI deploys the build to GitHub Pages (see "Needs owner").
- Balance: with player intervention only seed 1 of 5 survives 8 waves in the
  crude bot (`tools/balance_report.gd`); the bot runs out of refined essence.
  Consider cheaper turrets or turret cost in ore only.
- Repair costs / maintenance rules; deconstruct tool; wave direction warning.
- Storyteller events that break one link (design pillar 2).
- Stress & breakdowns (out of scope for this slice).

## Known issues
- Colonists ignore enemies when the alarm is off (no self-preservation).
- Forecast can improve a lot right after the refinery is destroyed (rate decays).
- Enemies pass through each other and colonists (no collision).
- Game-over overlay covers the map center.
- Pinch zoom only verified by code review, not in an automated test.
