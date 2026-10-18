# Endgame batch plan (source: docs/scout/endgame.md, ideas #1, #4, #5 + threats/hard-wave item)
One wave, 5 parallel workers (Sonnet, worktree). All: start with `git reset --hard claude/colony-sim-godot-4jftsm`; commit in the worktree, never push;
report <= 30 lines in `docs/agents/<agent>/E-report.md`; `sim/` deterministic (all rng via sim.rng); all tests green; in-game text English.
**Process safety: NEVER `pkill`/`killall` broadly (other workers' godot/chromium share the box). Kill only a PID you started. Leave no background test runs when reporting.**
Shared files (`simulation.gd`, `balance.json`, `event_bus.gd`, `hud.gd`) only inside `# region E<n>` (JSON: unique top-level key `"e<n>_*"`).

## Golden policy
- Only **E5** may run `make_golden.gd --regen` / edit `tests/golden/*`, and only for its own threats/hard-preset changes.
- E1-E4 gate every new sim behavior behind `e1_enabled`..`e4_enabled` (balance keys, **off by default**); their tests/bots switch it on in code. Each proves "goldens unchanged" via `tests/test_golden*`.
- After merge the orchestrator flips the keys on in one commit and does the single final regen.

## E1 Sentence Commutation Petition (idea #1). Owns: `data/petitions.json` (new), `sim/research/petition_system.gd` (new), `tests/test_e1_petition.gd`, `tools/petition_bot.gd`, region in `sim/core/simulation.gd`
- 4 staged deliveries at the warden terminal after audit tier 2, REPLACING the unreachable tier-3 wall (120 plate/40 parts/30 ingot): remove/redirect tier 3 in `data/milestones.json` to the petition (edit coordinated: E1 owns that key only).
  P1 60 plate + 20 parts; P2 + steel/copper ingot; P3 needs a power-chain item (battery/fuel cell, forces coal/nitrogen power); P4 refined essence (debt payoff).
  Each phase: one-time reward (unlock content / cut debt %), amounts preset-scaled from data. Commands: `Simulation.deliver_petition(phase)` (partial deliveries allowed), bus signal `petition_phase_done`.
- Accept (`e1_enabled`, standard, seeds 1..5, 40 d bot): petition phase reach P1 5/5, P3 >= 3/5, P4 >= 1/5; table by seed + day of each phase in report. Pacing ~P1 d12, P4 ~d35.
- Tests: staged delivery, partial credit, save/load, determinism (same seed twice), tier-3 wall gone.

## E2 Sector Dispatch (idea #4). Owns: `data/expedition.json`, `data/contracts.json` (dispatch tiers only), `sim/expedition.gd`, `sim/contracts/*`, `tests/test_e2_dispatch.gd`
- Launch-pad style "dispatch" slot: ship 100+ item bundles to the outer cell block; reward is a permanent modifier (-10% wave strength, +1 colonist, or a new recipe), one pick per tier, 3 tiers. Gate `e2_enabled`.
- Accept: expedition bot completes >= 1 dispatch tier on >= 3/5 seeds in 30 d, with modifier effect measured (wave strength) in the report; no change when off.

## E3 Chain Gang Review (idea #5). Owns: Parole Reviews 4-5 in `data/milestones.json` (reviews block only) + `sim/research/milestone_system.gd`, `tests/test_e3_reviews.gd`
- Review 4: debt < 5%. Review 5: "range score" = power surplus x clean-pollution factor above threshold (formula + thresholds in JSON). Rewards: lighter audits (patrol interval +1 d), cosmetic rank title. Gate `e3_enabled`.
- Accept: `tools/review_bot.gd` seeds 1..5, 40 d: reviews 1-3 unchanged (5/5), R4 >= 3/5, R5 >= 1/5; table in report.

## E4 Petition/Dispatch/Review UI. Owns: `view/panels/petition_panel.gd` (new), `view/panels/dispatch_panel.gd` (new), `view/panels/reviews_panel.gd` (extend), region in `view/hud.gd`, `tests/test_e4_ui.gd`
- Warden-terminal sheet: 4 petition phases with per-item progress bars + Deliver button (>= 64 px); dispatch tier list with pick-a-modifier; Reviews 4-5 lines; HUD chip "Petition P2/4". Read-only on sim; commands only via Simulation methods (stub against E1/E2 API in plan: `petition_state()`, `dispatch_state()`).
- Accept: panels build without errors with keys off and on; `tools/web_smoke.py` PASS at 844x390; screenshot per panel in report (scratchpad path).

## E5 Threats bench + hard waves. Owns: `sim/threats/*`, `data/threat.json`, `data/presets.json` (hard_time), `tests/golden/*`, `tests/test_perf_budget.gd`
- `perf_threat.gd` @250 map, 300 enemies: 2.2 -> <= 2.0 ms (profile flow-field/targeting; no behavior change, goldens must stay identical for this part).
- hard_time waves by d21: 7.2 -> ~8 (7.8-8.3) via preset/threat numbers from `tools/balance_report.gd`, not by eye; standard (6.6) and short (4.8) stay +-0.2; pollution still the main lever (baseline > throttle waves).
- Regenerates goldens once, last. Report bench before/after and the 3-preset waves table.

## Merge order and orchestrator checks
E5 (goldens) -> E1 -> E2 -> E3 -> E4. Full suite sharded x2, `tools/web_smoke.py`, then flip `e*_enabled`, one regen, merge to `main`. Merge only when the petition reach numbers (P1 5/5, P3 >= 3/5, P4 >= 1/5 over 40 d) are confirmed on the merged build.

## Next batch (deferred, do not build)
#2 Release Shuttle (final project, siege countdown, win = leave) after petition is stable; #3 Penance Beacons (decaying debt reducers, endless sink).
