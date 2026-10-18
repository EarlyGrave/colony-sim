# Scout: onboarding & phone UX (R5)
Verified live: Factorio FFF-241 (tutorial critique), RimWorld wiki "Learning helper", Satisfactory wiki (Tier 0 / HUB Upgrades).
Everything else (Mindustry, Frostpunk 2, Shapez 2, Bad North, Kingdom, Northgard, Rebel Inc.) is [memory].
Frame: the tutorial is the **Warden's Orientation for new inmates** (dry, bureaucratic voice; "Form 7: Dig"). Source: `data/tutorial.json`.

## Lessons from sources
- Factorio FFF-241 [verified]: over-restricted steps teach "how to solve the tutorial", and tasks without a reason feel arbitrary. So: every step gives a reason (stakes), never locks the UI.
- RimWorld learning helper [verified]: lessons queue top-right, fire by situation or slow timer, auto-complete when the player does the thing, browsable list. Never show a known lesson.
- Satisfactory Tier 0 [verified]: sequential, skippable ("skip onboarding" skips Tier 0), each step visibly changes the HUB.

## Ideas (cost S/M/L)
1. **Orientation Orders (linear chain)** - Satisfactory Tier 0 + Factorio. 10 steps (below), each ends with a visible reward (a building appears, a hatch opens), skippable in one tap. M. `data/tutorial.json`, `sim/tutorial/tutorial_system.gd`, `view/panels/tutorial_panel.gd`.
2. **Situational lesson queue** - RimWorld. Ledger of ~25 lessons (belt jams, broken building, ammo out, first mood break); fires on bus signals (`building_broken`, `ammo_depleted`, `colonist_downed`), auto-marks learned on the matching action. Voiced as "Inmate Handbook, par. N". M. same files + `data/lessons.json`.
3. **Handbook page** - RimWorld search list. "?" button lists all read lessons; replay any. S. `view/panels/handbook_panel.gd`.
4. **Ghost hint / pulse highlight** - Factorio's arrows, Shapez 2 ghost placement. One pulsing outline on the exact tool button or map cell; disappears on the first correct tap, never blocks input. S. `view/hud.gd`, `tutorial_panel.gd`.
5. **Pre-placed "guard's leftovers"** - Factorio forum: start with a small built base. Tutorial map seed starts with one ruined belt strip to repair, so step 5 teaches by fixing, not building from zero. M. `data/scenarios.json`, `tests/scenario.gd`.
6. **Dilemma demo, not text** - core pillar. Step 8 forces one small refining batch and shows the contamination bar rising plus the forecast; the player SEES cause and effect before any wave. S. step data only.
7. **Warden's audit as a gentle first raid** - first wave is scripted weak (1-2 creatures from a visible direction, `wave_incoming` telegraph), teaching alarm and turret without a loss. Fail-safe: tutorial wave cannot kill the capsule. M. `sim/threats`, `data/events.json`.
8. **Decoy lesson through consequence** - Mindustry-style "show the enemy target". After the raid, replay highlight: creatures went for the refinery; offer the cheap decoy (see scout 19 "Beacon"). S-M.
9. **Difficulty presets as sentences** - Sentence lengths: Short Stay / Standard Term / Hard Time (RimWorld storytellers Cassandra/Phoebe/Randy [memory], reframed). Each is a data bundle: wave strength, waste mult, debt, hint density. Golden hashes per preset. M. `data/scenarios.json`, R1b.
10. **Hint density slider** - RimWorld "learning helper on/off" + Frostpunk 2 style advisor [memory]: Full / Only-new / Off, saved in meta. S. `view/meta_store.gd`.
11. **Radial build wheel** - Northgard/Rebel Inc. style [memory]. Long-press a cell: 5-slot ring (mine, zone, build, belt, inspect) around the thumb; slots >= 64 px. Replaces menu hunting. M. `view/game.gd` input, new `view/radial_menu.gd`.
12. **Thumb-zone layout + big-target "reach mode"** - Bad North/Kingdom minimal UI [memory]: all frequent actions in the bottom corners, map unobstructed; swipe-up sheet for detail. M-L. `view/hud.gd`, `panel_registry.gd`.
13. **Drag-to-paint belts with auto-confirm** - Shapez 2/Mindustry mobile [memory]. One finger paints the path, lift = place, undo chip for 5 s. Already in W1/PROGRESS backlog. M. `view/world_view.gd`, `Simulation.place_belt`.
14. **Fix known phone bugs first** - W1: Orders panel overlaps portrait column, status line truncated, Russian vs English text. S. `view/panels/colonist_bar.gd`, `view/hud.gd`.

## Tutorial steps (condition checkable from sim state / bus)
1. Intake: pan and select a colonist - `selected_colonist != -1` (view flag mirrored via command `tutorial_ack`). Reason: "Inmate #1 will do your work."
2. Form 7, Dig: designate 3 mine cells - `designation_changed` count >= 3.
3. Storage: paint a zone - `zone_changed` count >= 4.
4. Haul proof: stored ore >= 10 - `item_mined` sum and ledger stock in zone.
5. First tool: place a workbench / hand-refiner - `building_placed` (def in hand-phase set).
6. Dirty hands: complete one batch - `first_refine_done`; step shows contamination bar rise (`contamination_changed`).
7. Research: start first tech - `start_research` recorded, then tech done (research_system state).
8. First belt: miner -> belt -> storage, 1 item delivered - belt cell count >= 3 and item arrives in zone.
9. Warden's audit: forecast shown - `forecast_revealed`; HUD forecast opened.
10. First inspection (scripted raid) - `wave_started` then `wave_repelled`; alarm used (`alarm_changed`) or 1 turret built.
11. Decoy: place the cheap decoy before wave 2 - `building_placed` decoy def; completion at `wave_incoming` of wave 2.
12. Release into general population - tutorial flag saved, hints switch to situational queue.
Each step: timeout nudge after N ticks (pulse highlight), "Skip step" and "Skip all" buttons, state saved in the save file (tutorial index) not in sim RNG.

## Phone layout 844x390 landscape (UI scale already by DPR)
- Left column (72 px): colonist portraits, 3 visible, scroll; no overlap with panels (panels start at x=80).
- Top strip (44 px): resources (left), contamination + forecast bar (centre), pause/1x/2x/3x (right). Status text goes to a tappable ticker chip, not a long label.
- Bottom-right thumb cluster: Build, Orders, Zones, Alarm as 64 px buttons; "More" opens a sheet. Left thumb: radial menu by long-press.
- Tutorial card: top-centre under the strip, max 2 lines + one 64 px button; map stays >= 64% of height.
- Sheets slide from the right (max 45% width) so the map remains visible; one panel at a time.
- Safe-area insets for notch; no hover, no right click; ignore emulated mouse events (already a rule).

## Suggested order
Fix bugs (14) -> hint card + highlight (4,1) -> scripted raid (7) -> situational queue (2,3,10) -> presets (9) -> radial menu (11).
Owner question: tutorial text in Russian only, or English with Russian on toggle (CLAUDE.md says code English)?
