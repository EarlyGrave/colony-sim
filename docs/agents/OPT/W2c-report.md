# W2c report: HUD at tick rate, int keys, building_3d sync (#8, #9)

- `view/hud.gd` (`# region W2c`): `_process` rebuilds all texts, counters (count_stored/count_world), threat/forecast strings,
  contract/alert/tutorial/squad refresh and `_o4_layout` at most every 0.1 s and only after a sim tick passed (0.5 s while paused);
  `Hud.invalidate()` forces it (called from `bind`). Opening/closing sheets and popups still lays out at once.
  Per-frame leftovers: alarm/rule button state, toast expiry, tutorial highlight while a lesson card is visible.
- `view/forecast_bar.gd`: redraws only when the contamination fraction changed.
- `view/world_3d.gd` (`# region W2c`): unit keys are ints (colonist `id*2`, enemy `id*2+1`) instead of "c%d"/"e%d"; the per-frame
  `seen` dict is reused. Only key type/scratch changed; W2b sprite logic untouched.
- `view/building_3d.gd`: static buildings are re-applied only when the tint/damage/cell signature changed; models, turrets and
  doors (animated/proximity driven) still update every frame; the removal pass runs only when node count != live count.
- Probe `tools/w2c_probe.tscn` (script time of `Hud._process` incl. panel refresh, fresh game, sim stepped every 2nd frame):
  closed 0.62-0.73 ms -> 0.12 ms; research open 0.57 -> 0.11 ms; expedition open 0.60 -> 0.11 ms.
- Screenshots before/after (xvfb, 900 ticks): identical layout and sprites; only the real-time clock text and a unit position
  differ (frame-timing noise).
- Not done: counters are not incremental (throttled to 10 Hz instead; `count_stored` already cached by W1d).
- Tests: `bash tools/run_tests_sharded.sh` twice; view-only change, goldens untouched.
