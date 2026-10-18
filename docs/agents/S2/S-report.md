# S2 Penance Beacons report
Gated by balance `s2_enabled` (false by default). Goldens untouched (full suite incl. golden tests green).
Files: data/beacons.json, sim/debt/beacon_system.gd (BeaconSystem), tests/test_s2_beacons.gd (6 tests), building `beacon_launcher` (2x2, 5 power, flat fallback in view/building_3d.gd until S3 model), regions S2 in simulation.gd/defs.gd/save_game.gd/event_bus.gd/balance.json/buildings.json, docs/sim_contract.md row.
Public API:
- `Simulation.get_beacon_state()` -> {enabled, alive, next_decay (tick, -1 none), debt_rate_cut (% of total debt/day), launched, total_cut, max_alive}
- `sim.beacons` (BeaconSystem): `rate_pct()`, `state()`, `enabled()`; bus signal `beacon_launched(alive)`.
- No new command: launcher placed via place_building; output is automatic from stored plate + refined_essence (no feed command needed).
Mechanics: launcher not broken/destroyed accumulates progress by power factor_for(b) per tick; at build_ticks (600) consumes 1 plate + 1 refined_essence (ledger sink "beacon") -> beacon lives 3 d. Daily: expired beacons dropped, each prisoner debt paid += ceil(total*rate%), never below 1 remaining (never completes payoff). Rate = sum 3%*0.8^i, cap 10%/day, max 8 alive.
Tuning numbers for S5 live in data/beacons.json (no bot run done; S5 owns bot numbers).
Tests: off-by-default, launch+ledger balance, broken pauses, decay+debt cut, cap/diminish, determinism.
Full sharded suite: 0 failed after fixes (3D fallback + contract doc rows).
