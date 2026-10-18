# R5X integration report (branch r5x-integration, base dc62af4, not pushed)
1. test_ui_batch3::test_hud_builds_with_crisis_and_contract: not a missing text. Headless viewport is 64x64, and O4's phone layout hides the Contract chip when there is no room. The test now sets an 844x390 root and keeps the same three asserts (contract chip, crisis banner, patrol/dummy tools).
2. O2 card now lives in `Hud.tutorial_slot()`. Panel targets are mapped: colonist_bar -> portrait dock, contamination/forecast -> ticker chip, tutorial_card -> card, research -> panel button. Cell target `stockpile` is projected through the camera (`GameController._r5x_cell_rect`) and drawn with `TutorialHighlight.show_over`. The view sends `tutorial_ack` via `Hud.o2_ack_if()`: intake on colonist select, forecast on ticker tap, release on any map tap. The card hides while a sheet leaves the slot under 420 px.
3. New-game dialog: "Warden's Orientation (tutorial)" toggle next to Start (both at the top, no scroll needed), opaque backdrop. `MetaState.tutorial` defaults ON for a fresh profile; `launched=false` opens the dialog at first start. Old profiles keep tutorial OFF. Tested in test_presets.
4. Bot reads `sim.tutorial.step` and uses opts `{tutorial, research_locked}` with the scripted raid. `research_audit_tiers` is dropped. O1 change: the tutorial pre-approves the T2 audit, because T0/T1 are free from the start and a real audit is out of reach. All 12 steps, 0 deaths:
   - seed 1: day 11.6
   - seed 2: day 10.9
   - seed 3: day 11.1
   Bot economy tweaks: 2 benches, no beds/workbench, 2 turrets, periodic re-designation. Margin to 12 days is thin; ore is the bottleneck.
5. Machines row overlapped the chips (reproduced in test_phone_layout at 844x390). Fixed: when open it drops into the toast/legend band. Added a scan state and reset `_message.visible`. Belt-layer gap: geometry is already seamless (1x1 quads on cell centres); the only visible "gap" is the 2 px yellow border in belt_tile.png, so no code change. Please confirm against the R4 screenshots.
6. Screenshots (2532x1170, scale 2.55, i.e. 993x459 logical): scratchpad/r5x_step1.png (card + portrait highlight), r5x_handbook.png, r5x_dialog.png, r5x_radial.png. Reviewed. `tools/screenshot.gd` gained --tutorial[=N] --nudge --dialog --radial.
Tests: run 1 full = 548 passed, 0 failed. Run 2 full = 548 passed, 0 failed.
DECISIONS.md: "R5 Orientation tutorial" entries added.
Known: dialog has no inner margin; the radial ring can overlap the belt strip.
