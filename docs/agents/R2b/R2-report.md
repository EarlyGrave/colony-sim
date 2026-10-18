# R2b report: Audit Deliveries

Branch: worktree branch of agent R2b (base 0fd972c). Not pushed.

## Added
- `data/milestones.json`: tiers "2" and "3" -> `parts` + `letter {title,text}`. T2 = 40 plate + 10 parts; T3 = 120 plate + 40 parts + 30 ingot_copper. (Plan guessed "gears": no such item; real ids `plate`, `parts`, `ingot_copper` verified by test.)
- `sim/research/milestone_system.gd` (`MilestoneSystem`, `sim.milestones`): `tier()`, `is_tier_done(t)`, `next_tier()`, `required(t)`, `remaining(t)`, `delivered` (tier -> item -> count, sorted on hash), `deliver(t)`, `state_parts()`.
- `warden_terminal` building (2x1, T0, 20 essence_ore, `"unique": true`); `placement_error` returns "Only one allowed" (counts blueprints too).
- Command `Simulation.deliver_audit(tier) -> bool` (recorded). Consumes only what is still required, from stored items (like contracts), only for `next_tier()`, only if a terminal exists. Partial deliveries accumulate; unlock emits `letter_received(title, text)` (new bus signal) plus `story_event`, once per tier.
- `tests/test_milestones.gd` (6 tests). Hash: `sim.milestones.state_parts()` added to `SaveGame.state_hash`.
- `data/zones.json`: stockpile now accepts ingot_copper, ingot_iron, plate, parts (not raw ores: that broke test_ports) (otherwise automation items were never "stored" and could not be delivered).

## Region R2b edits (shared files)
event_bus.gd, defs.gd (var/load/duplicate), simulation.gd (var, init, command at file end), save_game.gd (hash line), building_system.gd (unique check + `_blueprint_count`).

## Reconciliation with R2a (exact calls)
- Mine -> R2a: `sim.research.unlock_tier(n: int)` is called (guarded by `sim.get("research")` + `has_method`, so no stub needed) when an audit completes.
- R2a -> Mine: tier gating should read `sim.milestones.is_tier_done(t)` / `sim.milestones.tier()` (T0, T1 done at start). If `research_locked` is off (default in tests), ignore it.
- Not wired: `Simulation._init_systems` order (milestones created last); no tick hook needed.
- Terminal delivery uses the stored-item pool, not a hauling job (no new job).

## Tests
Full suite: 391 passed, 0 failed.
- Also: view/building_3d.gd FLAT_FALLBACK gets "warden_terminal" (test_building_3d requires an entry); R2c will touch the same line for research_bench.
