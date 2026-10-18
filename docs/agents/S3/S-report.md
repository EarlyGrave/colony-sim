# S3 report: models + win screen
Files: `view/world_view_shuttle.gd` (ShuttleView3D), `view/panels/win_screen.gd` (WinScreen), `tests/test_s3_view.gd`, `tools/s3_shot.gd/.tscn`; `view/world_3d.gd` hooks in `# region S3` (5 lines: add/bind/clear/sync).
- Models are procedural voxel boxes (no asset files, so no `assets/models/*`, no gen_art.py change): gantry 3 stages (towers / + upper towers and crossbeam / + beacon light and fuel tank), shuttle, beacon with glow, siege HP bar (red box scaled by hp/hp_max).
- Shuttle at ready/countdown sits on the gantry; at `won` it rises (launch pose).
- WinScreen: dim overlay, "SENTENCE ENDED", ending text (fallback text = plan text; pass flavor.json `shuttle_ending` as 2nd ctor arg), stats lines, signals `continue_pressed` / `new_run_pressed`, buttons 72 px.
- Not wired: nothing in game.gd/hud.gd shows WinScreen yet (orchestrator/S4: on bus `shuttle_won` build `WinScreen.new(stats, text)`; `WinScreen.stats_from(sim)` fills colonists only, days/debt_paid/pollution must be supplied by the caller).
- Screenshots: `docs/agents/S3/gantry_stages.png`, `docs/agents/S3/win_screen.png` (844x390, standalone scene via tools/s3_shot.tscn, not full-game).
Assumed sim names (all guarded): `sim.get_shuttle_state()` -> {phase in building/ready/countdown/won, parts, need, hp, hp_max}; `sim.get_beacon_state()` -> {alive}; building def ids `release_gantry`, `beacon_launcher` in `sim.buildings.list`; `b.cell` top-left.
Tests: test_s3_view 4/4 pass. Sharded suite: 735 passed, only failure was the test_s3_view compile error (make_sim arg), fixed afterwards and re-run alone green.
