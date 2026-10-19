# HUD batch plan (U1-U4) — one wave, 4 parallel workers

Problem (docs/agents/SX/countdown_siege.png, win_screen.png, 844x390): HUD covers most of the world; gantry barely visible; win overlay is transparent and text bleeds through.
Common rules: start with `git reset --hard claude/colony-sim-godot-4jftsm`; shared files only in `# region U<n>`; NO sim changes (except U4 under tools/); goldens byte-identical, nobody regenerates; touch targets >= 64 px; all in-game text English; all tests green; commit in worktree, never push; report <= 30 lines in `docs/agents/U<n>/hud-report.md`.
Hygiene: never `pkill` broadly (kill only your own PIDs); leave no background runs; write only inside the repo or a `mktemp -d` dir (TMPDIR); delete temp dirs at the end.
Screenshots (U1-U3): before + after via `xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn -- --out=$TMPDIR/shot.png` at 844x390; save the final pair as `docs/agents/U<n>/before.png|after.png`. Run `tools/web_smoke.py` (PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) before reporting.

## U1 HUD audit + layout (owns view/hud.gd layout, view/game.gd layout calls, tests/test_phone_layout.gd)
- Audit first: list every always-on HUD element with its rect at 844x390 (put in report).
- Target: >= 55% of the screen area is world (not covered by any HUD Control with mouse_filter != IGNORE or opaque fill) in the default state (no sheet open, no toast).
- Collapse the Belt/Remove/Rotate/Machines/Logic automation strip: show only while Build/Belt tool or a machine is active (context drawer).
- Collapse Home/Expedition/Cargo/Contract row into one small map-switch button/drawer; contract chip folds into it (badge count).
- Legend (tainted/mutated): auto-hide after ~5 s or show only while the taint overlay is on.
- Left colonist column: narrower/shorter (icons only, max 4 visible, scroll) if needed; right 6-button grid may stay but must not grow.
- All buttons stay >= 64 px; nothing overlaps the other sheets (existing tests must pass).
- Add to test_phone_layout a test `test_world_visible_percent`: builds the HUD at 844x390, sums uncovered area (union of visible HUD rects, exclude U2's notification stack when empty), asserts >= 55%.
- Hook points for U2/U3: expose an empty `NotificationAnchor` Control (top-right, below speed row) and `ModalLayer` (CanvasLayer/Control above the HUD) — create inside `# region U1`.

## U2 Notifications (owns new view/notification_stack.gd + tests/test_u2_notifications.gd; hooks in `# region U2`)
- One compact stack in the U1 NotificationAnchor (top-right), max 2 visible, newest on top, overflow shown as "+N" chip (tap to expand/clear).
- Merge sources: wave report strip, hint toasts, feed/event lines (feed_ticker, alert_center, bark_layer hints as appropriate). Each item: icon/colour by severity, one line, ✕ dismiss (>= 64 px tap area for the whole item), auto-expire (info 6 s, wave report 10 s, warnings sticky until dismissed or 20 s).
- Remove the old full-width wave-report strip and the yellow hint toast from the screen (route them via the stack API `Notifications.push(text, kind, ttl)`); the tutorial hint stays functional.
- Tests: max 2 visible, dismiss, expiry on real-time delta, dedupe of identical text, stack rect clear of speed buttons.

## U3 Modal polish (owns new view/modal_style.gd + panel files under view/panels/ for win/loss/other full-screen sheets; hooks `# region U3`)
- Shared helper `ModalStyle.apply(panel)`: opaque panel (>= 0.96 alpha dark), full-screen dim scrim 0.75 under it that blocks input to the world, 12 px rounded border, 18+ px font body, high-contrast title (WCAG >= 7:1 vs panel).
- Apply to: Sentence Ended (win), game over/loss, Reviews, Petition, Dispatch, Shuttle sheets (list in report which were converted).
- Win screen: primary button "New Run" (filled accent, >= 64 px), secondary "Continue" (outlined); stats in 2-column grid; fits 844x390 without scrolling; world not readable behind text.
- Test: a unit test computes contrast ratio of title/body/button text vs panel colour (>= 4.5:1 body) and asserts panel alpha >= 0.95 and button min height >= 64.

## U4 Real production bot (owns tools/factory_bot.gd, tools/factory_bot_report.gd, tests/test_u4_factory_bot.gd; no sim/view edits)
- Replace scripted supply in tools/petition_bot.gd / shuttle_bot.gd with a bot that really builds a factory through Simulation commands only: designate mining, place miners on ore/coal, smelters (iron, copper), belts into storage/machines, power (solar/generators), plate/part/fuel-cell lines, refined essence line, Taint cap rule.
- No item spawning, no ledger cheats; only public commands. Deterministic (sim.rng only; no Time/randi).
- Report per seed (5 seeds, standard preset, 60 d): petition phase reached (P1-P4), days of each, shuttle parts built (x/24), launched? day, siege result, debt paid %, deaths, planet_dead. Compare with the scripted bots in the report table.
- Keep the old scripted bots working (tests stay green); runtime of the new bot test <= 60 s headless (use fewer seeds in the test, 5 in the tool).
- Doc: add a 5-line "factory bot" section to the U4 report (what layout it builds, where it fails).

## Merge order / conflicts
U1 first (adds anchors), then U2, U3, U4 (independent). Orchestrator resolves region conflicts, runs full suite (sharded 4), web_smoke, takes final shot at 844x390, merges to main only when the whole batch is green.
