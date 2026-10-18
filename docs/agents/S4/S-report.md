# S4 report (shuttle/beacon panels + HUD chips)
Done: `view/panels/shuttle_panel.gd` (ShuttlePanel: parts bar, gantry HP bar, Launch button 64px, countdown line, static `chip_text`/`time_text`),
`view/panels/beacon_panel.gd` (BeaconPanel: alive, next decay, debt cut %), registry entries "shuttle"/"beacons" (region S4),
HUD `_s4_update` (region S4): both panel buttons hidden until state exists; shuttle button doubles as chip
("Shuttle 40/100", "Launch in 1d 3h", "Shuttle away"); beacons button shown only while alive > 0.
Tests: `tests/test_s4_ui.gd` (chip text, real sim keys off/on, stub with Launch press). Sharded suite: 738 passed, 0 failed. `tools/web_smoke.py`: PASS.
Assumed S1/S2 names (all guarded with has_method; absent -> empty state, buttons hidden):
- `Simulation.get_shuttle_state()` -> {phase: locked|building|ready|countdown|won, parts, need, t_left (TICKS), hp, hp_max (optional)}
- `Simulation.launch_shuttle()`
- `Simulation.get_beacon_state()` -> {alive, next_decay (TICKS), debt_rate_cut (0..1 fraction)}
- `sim.ticks_per_day` (exists) for time text. Balance keys s1_enabled/s2_enabled only used in the test.
If S1 uses hp as fraction or t_left in seconds, adjust ShuttlePanel. No per-panel screenshots taken (panels hidden while keys off).
