# I3 Contraband Stash + squad shakedown
- New: sim/society/contraband.gd (`sim.contraband`), data/contraband.json, tests/test_contraband.gd (5 tests).
- Shared (region I3): defs.gd (load), simulation.gd (member, tick after squads, command `squad_shakedown`), save_game.gd (hash part, only after first skim), threat_system.gd (`raid_points` * `contraband.wave_mult()`, exactly 1.0 when idle), sim_contract.md (2 rows, 2 blank lines removed, still 250 lines).
- Daily: inmates with despair >= despair_min skim 1 refined_essence from storage into a stash; total skim capped at 3% of ledger `recipe:refined_essence` output. Ledger: consumed `skim`, recovered = produced `shakedown`, leaked = event `contraband:leaked`.
- Shakedown (`squad_shakedown(sid)`): needs a living squad member, stash > 0, 1-day cooldown (the patrol day); stash returns at map centre, top holder +25 despair.
- Black market: stash >= 4 -> stash leaks, top holder's installment progress +1 (cap 2% of his debt cumulative), wave bump (0.15 + 0.002*contamination) for 2 days; Warden letter via `letter_received`.
- Invariant: skimmed == stash + recovered + leaked (tested 10 seeds); shakedown possible 10/10; skim <= 3% 10/10; determinism hash test.
- Default `enabled=false` (decided without owner, review): goldens identical by construction; flip in data/contraband.json to activate.
- Deviations: shakedown is a Simulation command not an Abilities entry (no weapons.json edit); debt_system.gd and item_system.gd untouched (read states directly).
