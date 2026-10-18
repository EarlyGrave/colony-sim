# O1 R5 report: tutorial engine

Done: `sim/tutorial/tutorial_system.gd`, `data/tutorial.json` (12 steps), scripted raid `tutorial_audit` in `data/raids.json` and `threat_system.gd`, commands in `simulation.gd` (region O1), `docs/sim_contract.md` (3 command rows, tutorial.json row, section 11), `tests/test_tutorial.gd` (12 tests).

API for O2/O3/O4/O5:
- Start: `Simulation.new(seed, bus, defs, {"tutorial": true})`; `sim.tutorial` is null otherwise.
- Commands (recorded): `tutorial_ack()`, `tutorial_skip_step()`, `tutorial_skip_all()`.
- Read: `sim.tutorial.step` (0..12), `step_count()`, `finished()`, `current()` (data row: id,title,text,reason,target{kind,id},done,nudge_ticks), `progress()` -> {have,need} or {}, `nudge_due()`, `is_done(id)`, `done[]`, `skipped`, `waves_held()`.
- Bus: `tutorial_step_changed(step)`, `tutorial_finished()`.
- Ack steps: intake (view sends `tutorial_ack` once a colonist is selected), forecast (ack when the forecast panel opens, or the signal), release (tap).
- Target ids used: tool mine/zone/build/belt/alarm, panel colonist_bar/contamination/research/forecast/tutorial_card, cell stockpile.

Decisions (log in DECISIONS.md): step 12 "release" completes by ack; `forecast_revealed` fires once at the first refine, long before step 9, so step 9 also accepts ack; first_refine/research/workbench are latched (steps complete on entry if already true); belt delivery is polled from port-building buffers (no edit to port_link.gd); player alarm is told apart from the wave's own via `sim.in_step`.
Audit raid: 2 crawlers, `wave_ticks` 1800, always counts as repelled at timeout, pod and inmates take 0 damage (harmless by design, defence is taught by the alarm/turret requirement). Normal waves held until the audit step.
Shared-file touches: `test_raids.gd` (skip scripted raids in the "reachable" assert), `save_game.gd` state_hash (tutorial part only in tutorial mode), `defs.gd`, `event_bus.gd`.
Tests: 20 seeds audit raid (pod hp constant, 0 deaths), replay equality, 12-step chain, skip_all, hold. Goldens unchanged (see full run).
