# T2 decoys report (branch worktree-agent-a57b25c43b52f5149)
- Buildings (data/buildings.json, end of file): `ash_beacon` (hp 300, threat 20, burns `waste` 1 per 300 ticks, +0.02 contamination per burn, unlit = 25%),
  `penitent_wall` (hp 800, threat 8, passive, not blocking), `mourning_bell` (hp 400, threat 6, burst x3 for 600 ticks, then cooldown 1800, 4 refined_essence per burst).
  All have `threat`, `threat_priority` (4-5, so the legacy targeting also prefers them), `repair_cost`, and a `decoy` block.
- Research (data/research.json, last 2 entries): `decoys_1` tier 2 (beacon, wall; needs fortification), `decoys_2` tier 3 (bell). Tier 1 is free at start, so tier 2/3 make the gate real.
  tests/test_research.gd counts updated (16 techs, [4,4,4,4]). Placement error `locked: decoys_1` comes from the existing R2a gate.
- Code: `sim/buildings/decoy.gd` (class Decoy), region T2 in building.gd (`decoy` state dict, `input_space` fuel-only), building_system.gd (`tick_decoys`, called first in `tick_machines`),
  simulation.gd (`trigger_bell(building_id)`, recorded), save_game.gd state_hash (decoy state only when non-empty, so existing goldens are unchanged).
- Models: voxel entries `ash_beacon`, `penitent_wall`, `mourning_bell` in data/models.json (bell has a swing group).
- Threat calls for T1: I did NOT define `Building.threat_now`. T1 should return `Decoy.threat_now(b)` when `b.def.has("decoy")` (applies unlit/burst multipliers; 0 if broken/destroyed),
  otherwise `float(def.threat)`. Decoy exposes `is_lit(b)`, `burst_left(b)`, `cooldown_left(b)`. Cap per region stays T1's job.
- Not done: hauling jobs to feed waste into beacons (belts/`add_input` work; colonist haul giver not wired); no view/HUD button for the bell; repair via T3's repair path (field `repair_cost` is ready).
- Bell essence: taken from storage, shortfall recorded as ledger event `decoy_essence_debt` (never blocks).
- Tests: tests/test_decoys.gd (7). Goldens: no regeneration needed. sim_contract.md: `trigger_bell` row and buildings.json row updated.
- Untested here (needs T1): "8 crawlers choose beacon over belt" acceptance, and real-save replay of a built decoy (no builders in empty-map tests; replay checked via two identical runs + command log).
