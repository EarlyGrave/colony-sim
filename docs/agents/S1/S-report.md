# S1 Release Shuttle sim - report
Gated by balance `s1_enabled` (false by default). Goldens untouched (no regen).
Files: data/shuttle.json, sim/shuttle/shuttle_system.gd (ShuttleSystem), tests/test_s1_shuttle.gd (7 tests).
Shared edits (all `# region S1`): simulation.gd, defs.gd (shuttle dict), event_bus.gd, save_game.gd (state_hash part, only once shuttle has state), balance.json, items.json (fuel_cell), recipes.json (fuel_cell at workbench: 2 nitrogen + 1 plate), buildings.json (release_gantry 4x4, 800 hp, power_use 20, threat_priority 6, non-deconstructible), zones.json (stockpile accepts fuel_cell).
Public API:
- Simulation.deliver_shuttle_parts() -> int (parts added; each part = 2 plate + 1 refined_essence + 1 fuel_cell from storage, ledger source "shuttle")
- Simulation.launch_shuttle() -> bool (phase ready: all parts, gantry, power factor >= 0.5)
- Simulation.repair_gantry() -> bool (10 plate, full HP)
- Simulation.get_shuttle_state() -> {phase: locked/building/ready/countdown/won, parts, need, t_left, hp, max_hp, launches, failures, part_cost}
- Bus: shuttle_phase(phase: String), shuttle_won(). sim.shuttle = ShuttleSystem.
Behavior: unlock = petition phase 4 done. need = 40 x preset_mult. Countdown 2 days; siege = ThreatSystem.start_wave() (public) every 1500 ticks, shortened up to 50% by pollution fraction (min 600); no sim/threats edits. Gantry destroyed in countdown -> fail: 50% parts lost, retry allowed. t_left <= 0 -> won (no end_game; Continue possible).
Save/load: command replay via _record; state_parts() joins state_hash only when has_state().
Tests: unlock gate, parts accounting, launch/win, siege wave + fail + retry, repair, determinism x2, command recording.
S5 note: siege strength is regular wave scaling (wave_index grows per siege wave); tune data/shuttle.json via bot.
