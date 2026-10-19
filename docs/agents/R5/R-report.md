# R5 report: quest sheet vs notification stack
- Fix: `view/hud.gd` `# region R5` adds `r5_sheet_overlaps(rect)`; the existing U2 suppress line also hides the notification stack while it would intersect the open quest sheet (toasts stay queued and reappear when the sheet closes). No sim changes, goldens untouched.
- Test: `tests/test_r5_ui.gd` (844x390 @ DPR 2.55, pending q1 choice + 2 toasts; visible stack must not intersect the sheet). Verified it FAILS without the fix.
- Passed: test_r5_ui, test_phone_layout (world-visible >=55%), test_u2_notifications (14/14).
- Screenshot: docs/agents/R5/quest_r5.png (--panel=quest_q1, 2532x1170 scale 2.55).
- NOT DONE: full sharded suite and web_smoke did not finish; host load avg ~20 from other workers (run exceeded ~60 min wall). Orchestrator should run both at merge.
