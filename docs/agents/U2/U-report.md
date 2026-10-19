# U2 notifications report
- New `view/notification_stack.gd` (NotificationStack): max 2 visible, newest on top, "+N more (tap to clear)" chip, items are 300x64 buttons (tap = dismiss), dedupe refreshes ttl, real-time expiry (info 6 s, wave 10 s, warn 20 s). API: `push(text, kind, ttl)`, `tick(real_delta)`, `clear()`, `dismiss()`, `expected_rect()`, `suppressed`.
- `# region U2` in view/hud.gd (bottom): `_u2_build/_u2_bind/_u2_update` + 4 one-line hooks (build, bind, update, `show_message`). `Hud.show_message` now routes to the stack (info, ttl >= 4 s), so the tutorial hint and all toasts keep working; old bottom-left `_message` label stays empty/invisible.
- Wave report: `bus.wave_report` -> stack ("wave", 10 s). The old strip text is hidden in `_u2_update` (the WaveReportCard ETA mode "Wave from ... in h" still shows; card file untouched so test_b5 stays green).
- Stack hides (suppressed) while a side sheet is open or its expected rect hits the feed ticker (keeps overlap scans green).
- Tests: tests/test_u2_notifications.gd (6: max 2, overflow chip, dismiss/clear, expiry, dedupe, 64 px, clear of speed buttons).
- Results: sharded suite 763 passed 0 failed, goldens untouched, web_smoke PASS. Screenshot: docs/agents/U2/shot.png (1280x720 from screenshot tool; 844x390 covered by layout tests + smoke).
## Reconcile with U1
- `_u2_build` uses `find_child("NotificationAnchor")` and adopts the stack into it; else fallback top-right offset_top 76. Once U1's anchor exists and sizes itself, drop the fallback branch and make sure the anchor sits clear of the speed row. U1's world-visible-% test should exclude the stack when empty (it is `visible=false` then).
- Remove the unused `_message` label / `_toasts` queue after U1 if desired (tests/test_squad_ui.gd references `hud._message`).
