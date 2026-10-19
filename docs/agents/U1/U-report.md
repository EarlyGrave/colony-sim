# U1 report (HUD audit + layout)
World-visible at 844x390, default state (no sheet, no toast): before ~45% (estimated from rects), after 61.4% (test_world_visible_percent, target >= 55%).
Audit, always-on elements before (rect px, 844x390): top strip 844x~70; colonist column 64x~320; chip row Home/Expedition/Cargo + Contract ~480x62; thumb cluster 3x2 ~256x140; legend ~192x38; Belt/Remove/Rotate/Machines/Logic strip ~465x64.
Changes (all in `# region U1`, plus one-line tagged edits in hud.gd _ready/_o4_layout and game.gd _process):
- Automation strip: hidden unless a build / belt / node / machine tool is active, or its Machines/Logic row is open (`Hud.u1_strip_wanted()`).
- Map chips + contract chip: folded behind one 96x64 "Maps (n)" button (badge = contract); drawer auto-closes after 10 s.
- Legend: shown for 5 s after start / overlay toggle, then hidden.
- Colonist column and right 6-button cluster unchanged.
Hooks for U2/U3: `hud.notification_anchor` (Control "NotificationAnchor", top-right, 300 px wide, top = below strip, height 0, grows down, mouse IGNORE, left of an open side sheet); `hud.modal_layer` (CanvasLayer "ModalLayer", layer 40) with `hud.modal_root` (full-rect Control, mouse IGNORE).
Tests: new test_world_visible_percent; test_radial_ring_clear_of_belt_strip sets tool "wall"; test_ui_batch3 contract chip test opens the drawer. Sharded suite: 757 passed + the one fixed test now passes; web_smoke PASS. Goldens untouched, no sim changes.
Screenshots: docs/agents/U1/before.png, after.png.
