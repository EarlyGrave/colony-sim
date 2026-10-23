# F11W3 report: passives numeric hooks + rule guards

Flag `passives_v2_enabled` untouched (false). `sim.passives` is called only as `mod(c, stat)` / `rule(c, x)` / `enabled()` / `state_of(c)`; flag off -> 0.0 / false, goldens byte-identical (test_golden green after every file). Quick suite (136 files, base 9ad44f4): 932 passed, 0 failed.

## Done
- 36/36 rules in `rule_consumers()` hooked; `tests/test_passive_hooks.gd` loops over them (one case each, holder vs control), plus cap / determinism / inert-when-unallocated / 30-day-run tests.
- Numeric `+ P` lines: mine_job, build_job, operate_job, repair_job, job_system (work_speed, flee_threshold), colonist.move_gain, needs (hunger, rest_gain), mood (mood_base, break_chance, thought_*), health (damage_taken cap -0.5 on the sum, tend_quality, heal_speed, infection_chance, bleed_rate), combat (hit, unarmed_hit, melee/unarmed damage, crit, attack_speed, armor_flat), threat (dodge, threat_attract), threat_model (target_weight), building_system (craft_input, waste_mult, machine_breakage, build_cost, building_hp >= 0.2), quality (craft_quality, quality_tier), mutation_risk, ammo_use, gear_wear, contamination_per_batch (-0.4 floor on perks+passives sum unless the uncapped rule), installment_pct (-0.4 cap), despair_mult, standing_gain, stash_cap, suspicion_gain, sale_price, xp_mult_*, carry.
- New helpers: `ContaminationSystem.add(batches)`, `Contraband.skim_ore()`, `CombatSystem.rage_mult()`, `BuildingSystem.craft_refused_for()`; `health.json` kind `letting`; `mood.json` thought `night_terrors` (-15).

## Notes for the orchestrator
- Golden dumps serialise Colonist/Injury properties, so a new field there changes goldens. No new Colonist/Injury vars here (field_tend uses `Injury.set_meta`). The stub keeps states in PassiveSystem; real W2 adds `Colonist.passives`: re-run `test_golden` after merging W2.
- Stub commit "STUB F11W2 (drop on merge)" is the LAST commit: `PassiveSystem`, `Simulation.passives`, `DebtSystem.credit()` (end of debt_system.gd). Real W2 must supply the same names.
- Left to W2 side effects: unequip on `no_armor` allocate (only the `equip` guard is here), `combat.resum` / threat refresh on allocate (target_weight, armor_flat, double_armor are cached until the next refresh), Informant re-pick (done at the next daily `blocks.tick`).
- Hooked but not test-covered: `medic` flee-override skip (needs a lockdown scenario); its blood-stop is tested.
- `essence_craft`: "craft" = workbench or gear_craft recipe; the +1 essence_ore comes from storage, and the operate giver skips the bench when none is stored. Covert sales have no seller, so `Contraband._seller()` picks the off_roll holder, else the best sale_price - suspicion_gain inmate (stash_cap sums over living inmates).
- `raid_first`: with such a holder in the stash a raid takes at most its normal size, his stash first. `ore_skim` units enter the stash without a ledger entry (the skimmed counter keeps conservation).
- `always_informant`: the existing picker uses no rng, so there is no draw to preserve.
- Could not hook: nothing skipped; all 36 rules have a guard.
