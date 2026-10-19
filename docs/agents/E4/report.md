# E4 report (bench + ranged params + gear panel)
Branch: this worktree branch (commit "E4: equip bench..."). Not pushed.

## Measured (desktop headless, loaded host, 250 map, 224 inmates x 6 legendary, 300 enemies in contact, 300 ticks after 100 warm-up)
- "combat" bucket = CombatSystem.try_attack (cooldown gate excluded, XP award excluded): avg 0.65-0.75 ms, p95 1.04-1.33 ms per tick (median of 3: 0.66 / 1.06). Budget in tests/perf_budget.json "combat": 0.6 / 1.5 (x1.5 noise margin enforced).
- ~25 attacks/tick -> ~25 us per attack on desktop (weapon_def 2 us, hit_chance 3.7, perks.mod x3 ~3, resolve_hit 2, damage_enemy 1, XP award 13 which is outside the bucket). Whole tick 28-31 ms in this scene (colonist jobs/threat movement for 224+300 units dominate, not gear).
- Equipment resums during the measured run: 0 (equip happens in setup; no per-tick equipment work). Same seed -> same state_hash and resum counts (test).
- Phone estimate: GDScript web ~10x slower -> ~6-7 ms/tick for the 224-unit melee brawl in the combat bucket; the 0.6 ms budget is a desktop number. The dominant cost is perks.mod/hit_chance/XP, not affixes (affixes are summed once per equip).

## Done
- tools/equip_bench.gd (CLI + shared `build/run_once`), tests/test_equip_perf.gd (budget, determinism, burst, magazine/reload, crit = 1 rng draw). PERF_SKIP / PERF_SKIP_WALL skip wall-clock asserts only.
- Integration gap fixed (region E4): StatBlock.IDX + sum_into(mult) + DAMAGE key (E2 code used them); EquipmentSystem._resum now calls combat.resum(); CombatSystem.resum copies equipment totals into att/def; weapon_def uses the equipped weapon base (cached per colonist, cleared on resum).
- Burst (shots/gap_ticks then cooldown) and magazine/reload (reload_ticks pause, no ammo spent) for any weapon with those keys; state kept in CombatSystem (_pattern), not CombatState, so goldens are untouched. Melee crit flows through resolve_hit (att[CRIT]).
- 3 new gear bases (work_gloves, greaves, underlay) so all 6 slots can be filled.
- view/panels/gear_panel.gd (inspector section "gear", >=64 px rows, read-only, only for inmates with gear) + tests/test_gear_panel.gd. No HUD change (nothing added to the HUD, so no overlap risk).

## Known
- tests/test_equipment.gd::test_socket_rules fails independently (rare vest rolls a random affix, expects flat_phys 5): E2/E3 interaction, not touched.
- Bench enemies use crawler with attack cooldown 2^28 and inmates hp 1e6 (resolve_hit floors damage at 1).
