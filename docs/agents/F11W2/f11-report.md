# F11W2 report - passives v2 core system

Done (flag `passives_v2_enabled` stays false; with it off every method is inert):
- `sim/perks/passive_system.gd` (`PassiveSystem`, `sim.passives`): `mod(c, stat)` (0.0 off), `rule(c, x)` (false off),
  `state_of(c)` (creates, credits milestones above join level), `peek(c)`, `can_allocate/can_undo/can_respec` (reason codes,
  "off" when disabled), `allocate/undo/respec`, `grant_marks`, `grant_deed`, `marks_free`, `dossier_of/apply_dossier`,
  `state_parts/hash_parts/load_parts/has_state`, `respec_cost`, `enabled()`, `tree` (PassiveTreeV2).
- Listeners (registered only when on): skill_leveled, colonist_joined, day_started (record deeds, quiet_days, first installment),
  debt_paid (installments + debt_cleared), colonist_rescued (carrier), colonist_tended (doctor), mood_break_started (reset quiet
  days), batch_refined (operator `batches` counter). `ColonistSystem.record_changed` calls `on_record_changed`.
- Keystone side effects: `no_armor` unequips non-weapon slots; `always_informant` calls `blocks._pick_informant()`; any keystone
  change re-sums `combat.resum` + `equipment._resum`.
- Simulation commands (recorded, replay-safe): `allocate_passive`, `undo_passive`, `respec_passives`, `grant_passive_marks`;
  listed in `docs/sim_contract.md`. 4 bus signals in `event_bus.gd`. `Defs.passives_v2` loaded only when flag on.
- `DebtSystem.credit(c, n)`; `SaveGame.state_hash` appends passive hash parts only when a mark exists; Legacy snapshot adds
  `passives` only when on, `MetaState` carries it into the dossier, `StartOpts` applies it to the veteran (one line, region F11W2).
- `tools/skill_model.gd --marks=60`: bot colony marks best/mean at day 10/25/45/60 (3 seeds). Result: d10 2-4, d25 8-9,
  d45 15-18 (matches earning.md); seed 1 colony died before d60.
Tests: `tests/test_passives_live.gd` (11): off-inert, milestones/baseline, deeds+counters, debt credit, allocate/undo/grace via
commands, respec cost+lockout+no-essence, 2-keystone cap, no_armor unequip, save round-trip hash, dossier, earning budget (3 seeds).

Notes / deviations:
- Per-inmate state lives in `PassiveSystem._states` (by colonist id), NOT `Colonist.passives`: golden dumps serialise every
  Colonist property reachable through storyteller.pending, so a new Colonist field changed goldens. Use `sim.passives.peek(c)`.
- Installments: `debt_paid` fires only on full clearance, so the first installment is detected on day_started (<= 1 day late)
  instead of editing `_pay`.
- `always_informant`: only calls `_pick_informant()` (no-op once picked); the guard inside it is W3's job.
- Respec uses path_mult "" (1.0); no ending-path lookup yet. Quest verbs (`passive_mark`, `passive_deed`) not added (sim/quests).
- StartOpts (W1 file) touched by one line inside `# region F11W2`.
