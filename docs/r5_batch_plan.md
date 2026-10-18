# Batch R5 "Orientation: tutorial, presets, phone UX" - plan (prompter)
Base: dev branch `claude/colony-sim-godot-4jftsm` AFTER the R4 expeditions batch is merged and green (so `Campaign`, `map_switcher` chips and R4 `# region` blocks exist in hud.gd/game.gd/event_bus.gd; do not break them).
One wave, 5 Sonnet workers, disjoint files; shared files only in `# region <agent>`. Report: `docs/agents/<agent>/R5-report.md` (<= 30 lines). No push. All in-game text English (Warden voice: dry, bureaucratic, "Form 7: Dig"). Source: `docs/scout/onboarding_phone_ux.md`.

## Design decisions (log in DECISIONS.md as "decided without owner, review")
- **Tutorial progress is sim-side** (`sim/tutorial/tutorial_system.gd`, RefCounted, no Node): it listens to the sim's own bus instance, holds `step:int`, `done:Array`, `skipped:bool`, ticks-in-step. Why: the scripted raid must be gated by the step (sim concern), headless bot/tests need it without a view, saves/replays stay consistent. Skips are recorded sim commands `tutorial_skip_step()` / `tutorial_skip_all()` (logged, replay-equal). The system never calls `sim.rng`; its state is part of `state_hash` ONLY when tutorial mode is on (opts `tutorial:true`), so all existing goldens stay byte-identical.
- View (O2) only reads `sim.tutorial` and draws; it never advances steps.
- Presets are start-opts bundles; none is the default, default opts == today's game.

## O1 tutorial engine
Owns `sim/tutorial/tutorial_system.gd`, `data/tutorial.json`, `sim/core/simulation.gd` (region O1: `tutorial` member, opts `tutorial`, commands above, scripted raid hook), `sim/threats/threat_system.gd` (region O1), `data/raids.json` (region O1: `tutorial_audit`), `docs/sim_contract.md` rows, `tests/test_tutorial.gd`.
- `data/tutorial.json`: 12 steps from the scout doc; each `{id, title, text, reason, target:{kind:"tool"|"cell"|"panel", id}, done:{signal, count|where}, nudge_ticks}`. Conditions use real signals: `designation_changed` (x3), `zone_changed` (x4), `item_mined`+stock in zone >= 10, `building_placed`, `first_refine_done`, `contamination_changed`, `research_completed`, belt cells >= 3 + item delivered, `forecast_revealed`, `wave_started`->`wave_repelled` + (`alarm_changed` or turret), decoy `building_placed` before wave 2 `wave_incoming`, step 12 = release flag. Step 1 (select colonist) completes by command `tutorial_ack` (view-mirrored, recorded).
- Scripted raid `tutorial_audit`: 1-2 weakest enemies, telegraphed by `wave_incoming`, fires when step 10 becomes active; in tutorial mode the capsule/HQ takes 0 damage from it and enemies retreat after 1800 ticks (cannot kill capsule). Normal waves are suppressed before step 10.
- Accept: replay of a recorded tutorial command list gives equal `state_hash` twice; each of 12 steps advances only on its signal (12 asserts); `tutorial_skip_all` -> step==12 and `done` flag within 1 tick; raid test: 20 seeds, capsule hp never drops, colonists_dead == 0 with no defences; goldens (non-tutorial) unchanged.

## O2 tutorial UI
Owns `view/panels/tutorial_card.gd`, `view/panels/handbook_panel.gd`, `view/tutorial_highlight.gd`, `view/hud.gd` (region O2), `view/panels/panel_registry.gd` (region O2), `tests/test_tutorial_ui.gd`.
- Warden card: top-centre under the top strip, <= 2 lines + reason line, one "Skip step" and one "Skip all" button (each >= 64 px), map area stays >= 64% of height at 844x390. Calls only sim commands.
- Highlight: pulsing outline (tween 1.0->1.15, 0.8 s) on the target tool button or map cell; `mouse_filter = IGNORE` (non-blocking); disappears when the step completes; appears after `nudge_ticks` idle.
- "?" handbook button (>= 64 px) opens a panel listing all 12 lessons (done = check mark), tap replays the text; `hint density` Full/New/Off saved via `MetaStore`.
- Accept: headless test builds card for each step, all buttons >= 64 px; highlight node has IGNORE filter and exists only for active step; skip buttons issue exactly 1 recorded command each; handbook lists 12 rows; zero script errors.

## O3 difficulty presets (prison sentences)
Owns `data/presets.json`, `sim/meta/start_opts.gd` (region O3), `view/panels/new_game_dialog.gd`, `view/panels/meta_screen.gd` (region O3), `tests/test_presets.gd`, `tests/golden/preset_*.json`, `tests/golden.gd` (region O3: SPECS rows only).
- Presets `short_stay`, `standard_term`, `hard_time`: fields `wave_strength_mult, waste_mult, starting_debt_mult, crate, hint_density`, applied only through `StartOpts.apply`; `standard_term` == current default (empty overrides).
- New-game dialog: three big cards (>= 64 px) with sentence text and one-line numbers, Start button; selected preset persisted in meta.
- Accept: golden hash per preset (3 new golden files, 3000 ticks, regenerated with `make_golden.gd`; existing 5 unchanged); strength order short < standard < hard on raid points at wave 3 (seed 2) by >= 15% each step; waste_mult scales contamination after one batch within 1%; dialog test: tapping each card sets opts exactly once.

## O4 phone layout pass
Owns `view/hud.gd` (region O4: layout only), `view/panels/colonist_bar.gd`, `view/belt_layer.gd` (strip gap/overlap fix), `view/panels/game_panel.gd` (side offset), `tools/screenshot.gd` (`--w/--h` presets), `tests/test_phone_layout.gd`.
- Layout: left 72 px portrait column (3 visible, scroll), side panels start x >= 80 (fixes W1 Orders overlap); top strip 44 px (resources | contamination+forecast | pause/1x/2x/3x), status text moves to a tappable ticker chip (no truncated label); bottom-right 64 px thumb cluster Build/Orders/Zones/Alarm + More; sheets max 45% width; safe-area insets.
- Fix the belt strip gap/overlap seen in R4 screenshots (adjacent belt cells render with 0 px gap/overlap at zoom 0.5..3).
- Accept: at 844x390 and 2532x1170 (DPR scale per `_apply_ui_scale`): no two visible Controls' rects intersect except intended overlays (assert via rect scan over HUD), every interactive Control >= 64 px, status label never ellipsized, portrait column right edge <= 72 px, panels left edge >= 80 px; two screenshots per size (idle, Orders open) saved by orchestrator; belt test: 2 belt cells at zoom 1 are exactly 1 cell apart (+-0 px).

## O5 radial menu + QA bot
Owns `view/radial_menu.gd`, `view/game.gd` (region O5: world-input long-press only), `tests/test_radial_menu.gd`, `tests/qa_tutorial_bot.gd`, `tests/test_qa_tutorial.gd`, `tools/tutorial_report.gd`.
- Long-press (>= 0.45 s, drift < 12 px) on a map cell opens a 5-slot ring (mine, zone, build, belt, inspect) around the finger, slots >= 64 px, no hover, no right click; events with `device == InputEvent.DEVICE_ID_EMULATION` ignored; tap on slot calls the same `select_tool` path; release outside closes. Does not conflict with pan/pinch (a moving finger cancels it).
- QA bot: drives only public `Simulation` commands, completes tutorial steps 1..12 in order; `tools/tutorial_report.gd` prints days per step for seeds 1..3.
- Accept: synthetic touch test (long-press fires after 0.45 s +-0.05, emulated events ignored, drift cancels, 5 slots each >= 64 px); bot finishes all 12 steps on seeds 1, 2, 3 within <= 12 game days each (N=12; report actual) with 0 colonist deaths and capsule alive; deterministic (same seed -> same finish tick).

## Merge order and risks
O1 first (sim + data), O3 (start_opts), then O2, O4, O5 (they stub missing sim API with `has_method`). Risks: hud.gd/game.gd conflicts between O2/O4/O5/R4 regions (keep edits inside region markers; O4 only touches layout functions); golden drift (run `test_golden` before commit); step ordering of tutorial vs R4 campaign (tutorial runs on home sim only). Out of scope: situational lesson queue, decoy replay highlight, Russian text, sound.
