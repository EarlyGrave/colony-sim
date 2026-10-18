# F5 report
- Recall: `ExpeditionPanel` (region F5) lists outposts on the destination step; "Recall <map>" (>= 64 px) asks inline Recall/Keep confirmation, then calls the real `Campaign.recall` once. Disabled with reason text while that outpost is the active map.
- New-game dialog: `MarginContainer` "Pad" 20 px on all sides; title no longer glued to the edges (buttons stay 88 px).
- Radial: `RadialMenu.avoid_provider` + `ring_hits`; `open_at` moves the ring to the nearest center whose slots clear the belt strip (game.gd region F5 `_f5_avoid`).
- Automation strip docked on the bottom edge (hud.gd region F5 inside the O4 layout); legend and toast stack above it.
- Tests: new tests/test_polish_fl.gd (recall, disabled recall, dialog margin, radial avoidance); test_phone_layout.gd gains a ring-vs-strip scan at 844x390, 2532x1170@2.55, 1280x720 with presses at centre/edges/corners.
- Sharded tests: 606 passed, 0 failed (run 1); run 2 result in the final message. Goldens untouched (view-only changes).
- Web smoke: `PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers python3 tools/web_smoke.py` -> WEB SMOKE PASS (tutorial + size250 boot ok).
- Screenshots (844x390 @2.55): scratchpad f5_dialog.png, f5_radial.png, f5_expedition_recall.png, f5_expedition_confirm.png, f5_idle.png; tool: tools/f5_shot.tscn.
