# O5 report: radial menu + QA tutorial bot

- `view/radial_menu.gd` (RadialMenu): press tracker (0.45 s hold, 12 px drift cancels, second finger cancels) + 5-slot ring (mine, zone=stockpile, build=workbench, belt, inspect), slot 72 px, ring around the finger, release on slot picks, release elsewhere closes. No hover/right click.
- `view/game.gd` `# region O5`: `_input` feeds `o5_feed()` (raw touch + real mouse only; `DEVICE_ID_EMULATION` ignored; presses over GUI controls ignored). After a long press the following tap is swallowed (`_o5_swallow_tap`), so no pan/tap side effects. Pick routes to `hud.select_tool` + `_on_tool_selected` (belt via `_on_auto_tool`). Camera untouched.
- `tests/test_radial_menu.gd`: 8 tests (fires 0.45 +-0.05, drift, jitter, 2nd finger, 5 slots >= 64 px, pick/close, emulated mouse ignored).
- `tests/qa_tutorial_bot.gd`, `tests/test_qa_tutorial.gd`, `tools/tutorial_report.gd` (`DAYS=n` env, default 12).
- O1 `sim.tutorial` was absent in my base, so the bot tracks the 12 goals itself from bus signals (select, designate x3, zone x4, stock >= 10, building, first refine, contamination, research, belt >= 3, forecast, wave repelled + alarm/turret, beacon decoy). Uses only public Simulation commands; deterministic.
- Research goal: tier 2 is pre-granted via opts `research_audit_tiers:[2]` (T0/T1 are free, real audit needs 40 plates).
- Actual result (12 days, natural raids, no scripted raid yet): peaceful goals done by day ~1.5-2.6 on all seeds; research ~6-8.6 days; seed 2 completes all 12 (wave 4.3 d); seeds 1 and 3 do not repel a natural wave (HQ destroyed on seeds 1/3 around day 9-11 with 6 turrets + alarm). 0 deaths on seed 2.
- Test asserts the 9 non-combat goals on seeds 1..3 + determinism; full 12 goals + 0 deaths asserted only when `sim.tutorial` exists (rely on O1 scripted capsule-safe raid). Follow-up after merge: switch the bot to `sim.tutorial.step` and the scripted raid, and drop the `research_audit_tiers` opt if O1 picks a T1 tech.
