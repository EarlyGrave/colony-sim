# O4 report (phone layout pass)
Worktree branch of agent-a8a494079e92e10ed (base 919903e). Not pushed.
- One layout on every size (844x390, 993x459 @2.55, 1280x720): 72 px portrait column (no scrollbar, touch-drag), top strip (resources | tappable taint+threat ticker -> Letters | 64 px speed), bottom-right 3x2 thumb cluster (Inspect Zones Build / Orders Alarm More, 80x64) that shifts left of an open sheet. Old bottom bar hidden; map share ~82% of height.
- Sheets: left >= 80, width <= min(340, 45%), top below strip. Category and More popups sit above the cluster, 88 px tall, horizontal touch-scroll (More is now one row).
- Bottom-left stack (x >= 80): legend, toast (3 lines, left aligned), belt strip / patrol bar. Legend, belt strip and Continue button hide while a popup or sheet is open (fixes ghost legend/Continue under sheets and toast vs toolbar).
- Tutorial slot for O2: `Hud.tutorial_slot()` (plain Control, mouse-ignore) under the strip, right of map chips/contract chip, shrinks beside an open sheet, hidden if < 200 px wide.
- Map chips and Contract chip float under the strip at x=80 (chips 96 px, font 16); Contract chip hides when a sheet leaves no room.
- Status text no longer ellipsized (shorter strings: "Taint x% · end ~d", "Wave in 3.2 h from the north"). The "to <crisis> x%" suffix is no longer shown (bar ticks still show it).
- Edits: hud.gd (`# region O4` plus small rewires in _check_layout/_apply_layout/_open_side/_place_side/_process), colonist_bar.gd (scrollbar off), game.gd region O4 (removed the R4X belt-strip visibility line; Hud owns it). Strip is ~70 px, not 44, so speed buttons stay 64 px.
- tests/test_phone_layout.gd: rect-overlap scan over visible Controls at 3 sizes in idle, 3 category popups, More, 5 sheets + expedition; buttons >= 64; column <= 72; sheets >= 80 and <= 45%; map >= 64%; labels unellipsized; slot usable.
- Not done: belt-layer cell gap (not in the brief), side-panel inner buttons below 64 px (panel internals untouched), expanded Machines row can overlap the chips at 390 px height.
- Screenshots: scratchpad o4_{phone,desk,dpr}_{main,build,zones,orders,research,exp_expedition}.png (belt strip is always visible in main).
