# C2 report: role abilities (taunt / volley / stabilise)
Branch `c2-abilities` (base dc62af4). Command `use_ability(squad_id, ability_id)` is recorded (`sim_contract.md` updated: command row, weapons.json, Colonist.threat_flags, state_hash note).

## Files
- New: `sim/squads/abilities.gd` (class `Abilities`, `sim.abilities`), `tests/test_abilities.gd` (7 tests).
- Data: `data/weapons.json` `abilities` {taunt, volley, stabilise}: role, cooldown_ticks, essence_cost (refined_essence from storage), contam_puff, noise_burst{mult,ticks}, taunt{mult 4, ticks 150, radius 6}, volley{shots 3, dmg_mult 2}, stabilise radius.
- Shared files, all inside `# region C2`: simulation.gd (var, init, `abilities.tick()` before threats, command), save_game.gd (state_hash part only after first use), combat_system.gd (`try_attack`: `abilities.take_volley`, volley shots auto-hit, dmg x2), threat_model.gd (`colonist_value` multiplies `sim.abilities.flags_of(id)` {flag:[until,mult,radius]}, kept off Colonist because adding a Colonist var shifts the storyteller golden dump; `score` drops radius-limited taunt beyond radius), event_bus.gd (`ability_used`).
- Contamination puff uses existing `sim.mutation.add_at(cell, amount)` (field cap 2.0, so puffs are 0.15/0.08); no new contamination API.

## Exact calls into C1 / C4 (all guarded)
- C1: `sim.get("squads")`, `squads.has_method("get_squad")`, `squads.get_squad(sid)` -> object with `members:Array[int]`, `role_of:{colonist_id: role}`. Roles must be "bulwark"/"lancer"/"medic". Until C1 merges, tests inject squads via `sim.abilities.set_test_squad(sid, members, role_of)`.
- C4: `sim.health.has_method("stabilise")` then `sim.health.stabilise(c, medic)` per Down inmate (`health.is_downed(c)`) within radius. Without it stabilise is rejected (no essence spent).
- C5 UI can query `sim.abilities.can_use(sid, id)` (reason string) and `ready_in(sid, id)` (ticks).

## Behaviour / numbers
Use costs essence exactly, sets cooldown (ready at use tick + cooldown, +-0), puffs contamination at user cell, sets `burst` x3 for 60 ticks; rejected use changes nothing. Taunt: 10 crawlers, equal distance -> >= 8/10 on Bulwark in window, < 5/10 after; flags erased on expiry. Volley: shots 1-3 deal >= 1.9x, 4th normal. Goldens untouched (hash part absent until first use).

## Tests
Full suite: 553 passed, 1 failed (known test_ui_batch3 red, unrelated). Golden: unchanged; Colonist/CombatState gained no vars (they feed the storyteller golden dump).
