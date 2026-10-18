# Shuttle batch plan (source: docs/scout/endgame.md #2 Release Shuttle, #3 Penance Beacons)
One wave, 5 parallel workers (Sonnet, worktree). All: start with `git reset --hard claude/colony-sim-godot-4jftsm`; commit in the worktree, never push;
report <= 30 lines in `docs/agents/<agent>/S-report.md`; `sim/` deterministic (all rng via sim.rng); all tests green; in-game text English.
**Process safety: NEVER `pkill`/`killall` broadly (other workers share the box). Kill only a PID you started. Leave no background runs when reporting.**
Shared files (`simulation.gd`, `balance.json`, `event_bus.gd`, `hud.gd`, `buildings.json`, `recipes.json`) only inside `# region S<n>` (JSON: unique top-level key `"s<n>_*"`).
Real APIs to build on (merged E batch): `Simulation.get_petition_state()` / `deliver_petition(phase)` (sim/research/petition_system.gd), `dispatch_sector(tier, modifier_id)` / `get_sector_state()` (sim/contracts/contract_system.gd), debt via `sim.debt` / `pay_debt`.
Commands go through `Simulation` methods with `_record(...)` for save-load, like E1/E2.

## Golden policy
- Only **S5** may run `make_golden.gd --regen` / edit `tests/golden/*`. S1-S4 gate new sim behavior behind `s1_enabled`..`s4_enabled` (balance keys, **off by default**); tests/bots switch on in code; each proves goldens unchanged via `tests/test_golden*`.
- After merge the orchestrator flips keys on in one commit; S5 does the single regen.

## S1 Release Shuttle sim. Owns: `data/shuttle.json` (new), `sim/shuttle/shuttle_system.gd` (new), `tests/test_s1_shuttle.gd`, regions in `simulation.gd`, `buildings.json`, `recipes.json`, `items.json`
- Unlock: petition P4 done (`petition.state()`). Building "Release Gantry" (4x4, needs 20 power); parts recipes "release_part" using plate + refined_essence + a power-chain item (battery/fuel cell); N parts (preset-scaled, data) delivered/crafted into the gantry.
- Commands: `Simulation.launch_shuttle()` (needs all parts, powered) -> countdown (data, ~2 d) in which a pollution-scaled siege targets the gantry (reuse ThreatSystem spawn API; gantry HP, repairable; no edits in `sim/threats/*`, call its public API only). Countdown survived -> state `won`; gantry destroyed -> countdown fails, parts partly lost, retry allowed.
- State: `Simulation.get_shuttle_state()` {phase: locked/building/ready/countdown/won, parts, need, t_left, hp}; bus signals `shuttle_phase`, `shuttle_won`.
- Tests: unlock gate, parts accounting (ledger), launch/siege/win/fail paths, save/load mid-countdown, determinism x2.

## S2 Penance Beacons. Owns: `data/beacons.json` (new), `sim/debt/beacon_system.gd` (new), `tests/test_s2_beacons.gd`, region in `simulation.gd`, building entry "Beacon Launcher"
- Building makes beacons (plate + refined_essence, 5 power draw); each live beacon cuts debt interest/balance by X%/day, decays after ~3 d, diminishing returns (cap in data). Endless sink, no win. Commands `place`-based plus `Simulation.feed_beacon_launcher()` if needed; state `get_beacon_state()` {alive, next_decay, debt_rate_cut}.
- Tests: decay, cap, power-off pauses output, ledger sink balance, save/load, determinism.

## S3 Models + win screen. Owns: `assets/models/*shuttle*`, `assets/models/*beacon*`, `tools/gen_art.py` (shuttle/beacon sections only), `view/world_view_shuttle.gd` (new), `view/panels/win_screen.gd` (new), `tests/test_s3_view.gd`
- Voxel/pseudo-3D models: Release Gantry (4x4, 3 build stages by parts, launch pose), shuttle, beacon + glow, siege HP bar. Win screen: dim overlay, "game ending" text (below), stats (days, colonists, debt paid, pollution), buttons Continue (endless) / New Run (>= 64 px).
- Reads sim only (stub to `get_shuttle_state()` / `get_beacon_state()`); builds with keys off/on. Accept: screenshot of gantry per stage + win screen (scratchpad path in report).

## S4 UI panels/HUD. Owns: `view/panels/shuttle_panel.gd` (new), `view/panels/beacon_panel.gd` (new), region in `view/hud.gd`, `tests/test_s4_ui.gd`
- Shuttle sheet: parts progress bars, Launch button, countdown timer, gantry HP; Beacon sheet: alive count, decay, debt cut; HUD chips "Shuttle 40/100" and "Launch in 1d 3h". Phone-size buttons; commands only via Simulation methods.
- Accept: panels build with keys off/on; `tools/web_smoke.py` PASS at 844x390; screenshot per panel in report.

## S5 Balance + bot + ending text. Owns: `tools/shuttle_bot.gd` (new), `data/balance.json` (`s5_*`, `s1_*`/`s2_*` numbers), `data/presets.json` shuttle scales, `tests/golden/*`, `data/flavor.json` (ending text key only), `tests/test_s5_bot.gd`
- Bot (extends petition_bot flow): petition P4 -> gantry -> parts -> launch -> defend. Accept (standard, seeds 1..5, 60 d): launch reached on >= 1/5 seeds, win survivable with defenses (siege win rate >= 50% of launches; table seed/day of P4, launch, outcome); tune from `tools/combat_model.gd`/`balance_report.gd`, not by eye. Beacons: debt cut measurable in bot run.
- Ending text (English, ~40 words in flavor.json `shuttle_ending`): "The gantry lights burn through the night. You rise above the grey sky, debt unpaid but sentence ended. Below, the planet keeps its poison and its teeth. Somebody else will be sent to dig."
- Regenerates goldens once, last. Report bot table.

## Merge order and orchestrator checks
S1 -> S2 -> S5 (numbers) -> S3 -> S4. Sharded suite x2, `tools/web_smoke.py`, flip `s*_enabled`, one regen, merge to `main` only if the bot table is confirmed on the merged build.
