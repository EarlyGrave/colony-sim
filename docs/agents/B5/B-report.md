# B5 report: wave readability and phone UI
- New `view/panels/wave_report_card.gd` (WaveReportCard): ETA marker ("Wave from the X in N h") from wave_incoming; post-wave card (kills, buildings lost with "Targeted by <attacker>" / "Collateral damage", main attack, inmates down) with OK dismiss, auto-hide 20 s. Pure view sampling of enemy targets.
- Bus: `wave_report(report: Dictionary)` in `# region B5` of autoload/event_bus.gd, emitted by the card at wave_ended (no sim change).
- HUD: region B5 in view/hud.gd (build/bind/update). Screenshot: docs/agents/B5/report_card.png (844x390; `tools/screenshot.gd --wavereport`).
- Radial menu: Miner/Smelter/Assembler slots added (8 total), routed to the automation tool; strip kept (Belt/Machines/Logic) so test_phone_layout bottom-gap assertions stay green. Strip gap not further changed (test asserts 4-16 px dock, passes).
- F11: `data/roles.json` bulwark dmg_taken_mult 0.45 -> 0.40. Model (`Model.squad_damage_delta`, threat-weighted): before -29.7%, after -32% (target <= -30). Bulwark lasts 2.5x inmate; Lancer TTK 40% of rifle. Goldens untouched (test_golden green, no regen).
- Tests: tests/test_b5_wave_report.gd (new), test_radial_menu slot count 5 -> 8.
- Full sharded suite: 684 passed, 0 failed. web_smoke.py: PASS. test_phone_layout green.
- Not done: real-device measurement; a true merge of the whole automation strip into the radial; the -11% -> -30% claim is model-based only (no bot run).
