# Design batch B plan (source: docs/design_review_s4.md, fixes F1-F12)
One wave, 5 parallel workers (Sonnet, worktree). All: start with `git reset --hard claude/colony-sim-godot-4jftsm`; commit in the worktree, never push;
report <= 30 lines in `docs/agents/<agent>/B-report.md`; `sim/` deterministic (all rng via sim.rng); all tests green; English in-game text.
**Process safety: NEVER `pkill`/`killall` broadly (other workers' godot/chromium run on this box). Kill only a PID you started yourself.**
Shared files (`simulation.gd`, `balance.json`, `rules.json`, `event_bus.gd`, `hud.gd`) only inside `# region B<n>` blocks (JSON: a unique top-level key `"b<n>_*"`).

## Golden policy (critical)
- Only **B1** may run `make_golden.gd --regen` and edit `tests/golden/*`, and only for its own data changes (research costs, presets).
- B2/B3/B4 gate every new sim behavior behind a balance key `b2_*`/`b3_*`/`b4_*` that is **off by default** (`enabled:false`) so goldens stay byte-identical;
  their tests and bot runs switch the key on in code/opts. B5 touches no sim numbers except weapons/roles via model (see B5).
- After merge the orchestrator flips the keys on in one small commit and does a single final golden regen. Each worker proves "goldens unchanged" by running `tests/test_golden*` before reporting.

## B1 Pacing and presets (F1, F3). Owns: `data/research.json`, `data/presets.json`, `tests/golden/*`, `tests/test_presets_ramp.gd`
- T0/T1 bench_ticks x3; small essence costs on drilling/conveyance/smelting techs (keep tutorial doable: tutorial T2 pre-approval still works).
- Presets as a ramp: short_stay waste 0.6 / wave 0.6; hard_time wave 1.15 / waste 1.15; add `hq_hp_mult`/`death_mult` key if needed (minimal read in preset loader only).
- Accept: tutorial bot (`tools/tutorial_report.gd`) hand phase (first refine -> first belt) >= 3 d and tutorial still releases by d14; preset bot table (bot_report, seeds 1..5, 25 d):
  deaths hard_time >= 1.5x standard, short_stay waves repelled >= standard +1, pol% d20 short_stay <= standard - 15 pts. Paste the table in the report.
- Tests: preset ramp test (numbers from data), existing tutorial tests updated, goldens regenerated once.

## B2 Pollution runaway and clean mining (F2, F4). Owns: `sim/contamination/*`, `data/threat.json`, key `b2_*` in `data/balance.json`, `tests/test_b2_pollution.gd`
- Faster natural decay when refiners idle / below threshold; bigger crop+mood reward for `refine_cap` throttling; creatures ignore mining outposts below pollution X; clean-ore contract bonus (key only, `data/contracts.json` value edit coordinated with B4: B2 adds `clean_bonus` field, B4 does not touch it).
- Accept (with `b2_enabled`): throttling bot (refine_cap) standard seeds 1..5: pol d20 <= 60% avg and no planet_dead by d25; non-throttling bot unchanged +-3 pts; mining-only bot (no refiner) survives 25 d on all 5 seeds. Use `tools/forecast_model`-style table in report; do not tune by eye.

## B3 Mid-game goals and throttle rule (F7, F8). Owns: `data/milestones.json`, `sim/research/milestone_system.gd`, `data/rules.json` (region), `tests/test_b3_reviews.gd`, rule hook region in `sim/core/simulation.gd`, HUD review strip file `view/panels/reviews_panel.gd` (new)
- 3 "Parole Reviews" after tutorial release (debt paid %, audit T3, repel N waves) with essence/perk rewards; rules `auto_throttle_above` (stop refining above contamination X) and `evacuate_low_hq` (colonists to HQ below hp Y); default off.
- Accept: tutorial-then-free bot completes all 3 reviews within 25 d on >= 4/5 seeds; with rules on, QA r3 seed 3 (hq_destroyed hard_time) survives to d25. Reviews deterministic (replay test: same seed + commands = same state).

## B4 Repair and expedition purpose (F5, F6). Owns: `data/recipes.json`, `data/contracts.json` (except `clean_bonus`), `data/crises.json`, `view/expedition_dialog.gd` + map switcher Recall button, `tools/bot_report.gd` (plate stocking only), `tests/test_b4_repair_exped.gd`
- Hand-phase `plate` recipe from scrap at HQ/bench (no T2); belt repair consumes it. >= 1 contract and 1 crisis demand a cinder/prism/bog item (key `b4_exped_demands` off by default); Recall button in UI.
- Accept (`tools/qa_r3.gd`, 5 seeds, 25 d): belt repairs > 0 on every seed (was 0); a bot with `send_expedition` completes the expedition contract on >= 3/5 seeds; Recall returns the party (test).

## B5 Wave readability and phone UI (F10, F11, F12). Owns: `view/hud*`, `view/panels/*` (except reviews_panel.gd), `data/flavor*`, `data/weapons.json`, `data/roles.json`, `tools/combat_model.gd`, `tests/test_b5_*.gd`
- Post-wave report card (buildings lost, attacker -> target, reason), wave ETA marker, merge automation strip into radial menu, fix strip gap. New bus signal `wave_report` declared in a `# region B5` of `autoload/event_bus.gd`; any sim emission is a pure read of existing data (no goldens change).
- F11 squad tuning via `combat_model.gd` table only: target deaths per repelled wave -30% (was -11%); update `test_combat_model.gd` targets. Weapons/roles edits that alter goldens must be reported to the orchestrator, not regenerated.
- Accept: overlap-scan/`test_phone_layout` green at 844x390; `tools/web_smoke.py` PASS with a screenshot of the report card; model table in report.

## Orchestrator after merge
Merge B1 first, then B2..B5; flip `b*_enabled` keys; one golden regen; full sharded suite + `qa_r3` table re-run + `web_smoke.py`; update PROGRESS/DECISIONS; merge to `main` only if all green.
