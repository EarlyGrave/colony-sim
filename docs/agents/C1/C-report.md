# C1 report: squads "Wardens of the Line"
Branch `c1-squads` (base dc62af4). New: `sim/squads/{squad,squad_system}.gd`, `data/roles.json`, `tests/test_squads.gd` (11 tests).
Shared edits only in `# region C1`: `simulation.gd` (var, ctor, `squads.tick()` after threats, 4 commands), `defs.gd` (`roles`), `save_game.gd` (hash), `traits.json` (`role_affinity` on strong/careful/hasty).
## API (Simulation)
- `form_squad(ids, roles = []) -> int` (squad id or -1). ids/roles: Array or JSON text; recorded as text. role "" / "auto" = by affinity.
- `disband_squad(sid) -> bool`, `squad_hold(sid, cell) -> bool`, `squad_focus(sid, enemy_id) -> bool`.
- Read: `sim.squads.list`, `get_squad(sid)`, `squad_of(colonist_id)`, `suggest_roles(ids)`, `affinity(c, role)`; `Squad{id,name,members,role_of,hold,focus,slot_cell}`.
- Data: `sim.defs.roles` = roles.json (max_size, order, roles{weapon,dmg_taken_mult,threat_mult,formation_offset,affinity_skill,ability}); C2 adds `abilities`, C5 `militia` (own regions).
## Behaviour
- Forming drafts members and swaps in the role weapon (restored on disband). Hold: offset cell (+ slot_spread for duplicate roles), nearest free reachable cell within radius 3.
- Focus: non-medics `order_attack`; when the target dies, focus clears and members return to their slots (`tick()`).
- Death removes a member; empty squad deleted. `state_hash` includes squads only while one exists (goldens unchanged).
- Manual `order_*` on members still works; plain draft path untouched.
## Docs
sim_contract.md: 4 command rows, roles.json row, section 12 (231 lines). DECISIONS.md: owner decision logged.
## Tests
test_squads 11/11; full suite 557 passed, 1 failed (known test_ui_batch3, fixed elsewhere); goldens unchanged.
