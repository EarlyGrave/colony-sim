# Batch I "Inmate Society" - plan (prompter)
Base: dev branch `claude/colony-sim-godot-4jftsm` (workers start `git reset --hard` to it). Source: `docs/scout/inmates.md`, `docs/story/bible.md`. Decided without owner, review (log in DECISIONS.md).
One wave, 4 Sonnet workers (worktree), disjoint files; shared files ONLY inside `# region <agent>`. Report <= 30 lines: `docs/agents/<agent>/I-report.md`. No push. Run only `tools/run_tests_quick.sh` and `tools/factory_eval.sh --jobs=3`. All gameplay numbers in `data/*.json`; `sim/` deterministic (`sim.rng` only, stable iteration order, no Time); in-game text English, <= 70 chars/line, Warden voice. Each worker adds <= 6 rows to `docs/sim_contract.md` (file is 250 lines; cap is 250, so each condenses/merges an existing row to stay <= 250 total, rows only inside its own `<!-- region <agent> -->`).
**Do NOT touch** (worker LN owns): `tools/factory_bot*`, `sim/shuttle/*`, `data/shuttle.json`, quest_log consumers of `essence_drop_mult` / `review_sponsored`. If a hook is needed there, add it as a new mod name read only by your own code.
Hash rule: new state enters `state_hash` only when the feature is active (non-empty), so the 5 existing goldens stay byte-identical; new golden files only if the worker regens via `make_golden.gd` and lists changed ticks.

## I1 Cell Block Standing
Owns `sim/society/block_system.gd` (new, `sim.blocks`), `data/blocks.json` (new), `tests/test_blocks.gd`. Regions: `sim/colonists/generator.gd` (assign `block` from bible archetypes Lifer/Clerk/Zealot/Informant/Fresh Fish; consumes generator rng at a fixed point), `sim/debt/debt_system.gd` (`_daily` hook: per-block despair mult), `sim/mood/mood_system.gd` (block thoughts), `sim/core/simulation.gd` (member + tick + hash part), `autoload/event_bus.gd` (`block_standing_changed`).
- Standing 0-100 per block: + on installment paid on time, - on member death/dock/missed installment. Low Standing multiplies that block's `despair_per_day` (cfg in blocks.json). Warden "Cohesion fee" line when a block stays quiet. Informant block is exactly 1 colonist/run when >= 6 inmates (exposes `sim.blocks.informant_id()` for I2).
- Accept: same seed + commands -> equal hash (2 runs); bot 10 seeds/60 d: breaks+riots within 15% of baseline, per-block despair spread (max-min) > 0 in >= 8/10; Standing always in [0,100]; save/load round-trip keeps Standing.

## I2 The Informant quest + petition_fee_mult
Owns `data/quests_q13.json` (new data quest), `sim/society/informant_mod.gd` (new, small), `tests/test_informant.gd`. Regions: `sim/quests/quest_log.gd` (register file in the fallback list; NO edit to essence_drop_mult/review_sponsored code), `data/flavor.json` (Warden lines), `docs/sim_contract.md`.
- Depends on I1 only via `informant_id()`; until merged, fall back to "first colonist with trait/flag informant", and test with a stub (no cross-worker file edits).
- Trigger: day >= 12, informant alive. Daily report -> mod `petition_fee_mult` 1.1-1.3 (cfg in json) while informant alive/unresolved. Options: tolerate (+fee, ration cut to him), feed false info (needs a Clerk; costs a clerk work-day), transfer (removes the worker, ends reports, mult back to 1.0). Debt reductions stay clamped to the 2% cap.
- Accept: 10 seeds/60 d: quest fires >= 7/10; mean `petition_fee_mult` > 1.0 while alive and == 1.0 after resolve (assert both); mid-quest replay hash test like Q6; each option reachable and covered by a test; no script errors.

## I3 Contraband Stash + squad shakedown
Owns `sim/society/contraband.gd` (new), `data/contraband.json` (new), `tests/test_contraband.gd`. Regions: `sim/debt/debt_system.gd` (read despair, separate region from I1), `sim/items/item_system.gd` (stash counter, `lost` bucket reuse), `sim/colonists/squad*.gd` or role/ability file (new ability `shakedown`, costs a patrol day), `sim/threats/threat_system.gd` (threat bump), `view/` only a one-line HUD/notification via existing bus (no new panel).
- Inmates with despair >= cfg skim refined essence daily into stash (<= 3% of refined output per seed). Shakedown recovers stash, spikes that inmate's despair. Ignored stash >= cfg -> black-market event: one installment reduced by 1 unit (clamped by 2% cap) AND a mimic wave bump (contamination-linked).
- Accept: skim volume <= 3% of refined output (10 seeds); shakedown possible in >= 8/10 seeds; recovered + leaked + skimmed ledger balances exactly (conservation test); determinism hash test; disabled by `contraband.enabled=false` -> goldens identical.

## I4 haul_blocked_fix balance pass
Owns `docs/agents/I4/*`, `data/balance.json` (region I4: `haul_blocked_fix` only), `sim/jobs/givers/haul_giver.gd` (only if a balance bug), `tests/test_haul_fix.gd`. Read-only: `tools/factory_eval.sh`, `tools/kx_pillar_table.gd`.
- Run factory_eval 10 seeds/60 d with fix off vs on (`--jobs=3`), plus `kx_pillar_table.gd` for standard_term d21: baseline 6.2 vs throttle 4.0 (pillar = baseline minus throttle waves-gap must stay >= 2).
- Decision rule: ON only if (alive>=8 >= 8/10) AND (audit tier 2 >= 7/10) AND pillar gap >= 2 AND raid survival not lower than off by > 1 seed; else stay OFF and document numbers in the report + DECISIONS.md. Do not tune other balance keys.
- Accept: table (off/on) in report; test asserts the flag value matches the decision and the default-off path hash is unchanged; goldens unchanged if OFF, regenerated (changed ticks listed) if ON.

## Merge order / orchestrator notes
I1 -> I2 (needs informant_id) -> I3 -> I4 last (balance measured on final sim). Run quick tests after each merge, full sharded suite + `web_smoke.py` before `main`. Re-run factory_eval once after all four to confirm alive>=8 stays 8/10.
