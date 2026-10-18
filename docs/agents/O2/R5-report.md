# O2 report (R5): tutorial UI
Done: Warden card (`view/panels/tutorial_card.gd`), pulsing non-blocking highlight (`view/tutorial_highlight.gd`), "?" handbook (`view/panels/handbook_panel.gd`, registered in `panel_registry.gd` region O2), HUD glue in `view/hud.gd` region O2 (`_o2_build/_o2_bind/_o2_update`, 3 one-line call sites), hint density in `view/meta_store.gd` region O2 (`user://hints.json`, Full/New/Off). Tests: `tests/test_tutorial_ui.gd` (5).

Sim API the view calls (all behind `get()`/`has_method` guards; absent => nothing shown, no errors). O1 MUST provide:
- `sim.tutorial` (Object): `step:int` (0-based current lesson, 12 = finished), `skipped:bool`, optional `steps:Array` (else `data/tutorial.json`, top-level Array or `{steps:[...]}`; step dict keys `title,text,reason,target{kind,id},nudge_ticks`).
- Commands `sim.tutorial_skip_step()` and `sim.tutorial_skip_all()` (one call per button tap). `tutorial_ack()` is NOT called by O2 (O5/game does the select-colonist mirror).
- Done mark in handbook = lesson index < `tutorial.step`.

Behaviour: card hidden when no tutorial, finished, or density Off; highlight appears after `nudge_ticks` (x2 for "New") since step start (ticks counted by view from `sim.tick`), hides on step change; target tool inside a closed category falls back to the category button, panel target falls back to More. `kind:"cell"` targets are not drawn yet (need camera projection; `TutorialHighlight.show_over(rect)` is ready for game.gd/O5).
Screenshots (stub lesson, tutorial API absent so driven by a temporary script): scratchpad/o2_card.png, scratchpad/o2_handbook.png.
Known: card with 64 px buttons is ~80 px tall, so at 844x390 the 64% map-area target depends on O4's slimmer top strip (R4 map chips row also sits above it). Card sits below `_stack`, left edge 92 px in compact mode (clear of portrait dock), right edge clears an open side panel.
