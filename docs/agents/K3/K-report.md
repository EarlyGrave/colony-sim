# K3 report (view-only)
- hud.gd `# region K3`: top-bar chip "Next audit in Nd" (64 px tall, 140 wide), reads `sim.threats.days_to_audit()` via has_method guard; hidden when absent or no room; tap opens Reviews sheet; red tint at <=1 day; "Audit today" at 0.
- reviews_panel.gd `# region K3`: extra read-only lines (audit countdown; K2 outpost step via `sim.milestones.outpost_step_text()` if it exists - K2 should add that getter or tell the orchestrator the real name).
- tests/test_k3_hud.gd: chip text for 0/1/3 days. Hidden-without-audit covered by test_phone_layout (K1 absent now).
- Suite: 702 passed, 0 failed. web_smoke.py exit 0. Screenshot docs/agents/K3/shot.png (chip hidden because K1 not merged yet).
- No sim edits. Per-preset demand display is not done: K2 getter names unknown; wire after merge.
