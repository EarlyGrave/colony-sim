# F11W5 report: bot + balance + eval harness
- Commit 1 `STUB F11W2 (drop on merge)`: sim/perks/passive_system.gd (state_of/mod/rule/can_allocate, skill-milestone marks) plus `Simulation.passives` / `allocate_passive` in `# region F11W2 STUB`. Drop when W2 merges (W2 owns both).
- `tools/factory_bot.gd` region F11W5: env `TRAITS_V3=1` / `PASSIVES_V2=1` set balance flags on the shared default Defs (tools only); `f11_pick` (best skill -> card, keystone > notable > minor, data order, only `Simulation.allocate_passive`, every 600 ticks when `sim.passives.enabled()`); `f11_stats`; `TRAIT_ASSIGN=1` (implied by TRAITS_V3) orders the crew by `sim.traits.mod(c,"work_speed")`.
- `tools/factory_eval_summary.py` prints marks earned/spent/keystones/rules and a >= 80% spend check; `factory_bot_report.gd` adds the `f11` key to EVALJSON (one line outside the owned list).
- `tools/balance_report.gd` prints `passives: marks earned/spent/keystones/rules` per seed when the flag is on. `tools/combat_model.gd` section 4: rows for Dead Man Walking, Short Fuse (mood 20/50/80), Armourer's Pride, Full Auto, per-passive model value and the > 1.5x school-median list (19 of 90).
- `tests/test_bot_passives.gd`: 7 tests, green. `tests/qa_bot.gd` untouched (no change needed).
- Results, flags ON, 60 days, seeds 1-3: 0 script errors, 161/169 marks spent (95%). Flag OFF: factory_bot_report seeds 1-3 identical to 9ad44f4.
- Numbers: docs/balance/f11_passives_table.md. Bot rows are [STUB]: re-run after W2/W1/W3 land (0 keystones now because the stub has no deeds).
- Not run here: quick/full suite (only test_bot_passives and the eval runs); run after merge.
