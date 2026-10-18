# W1 web build QA (main @ 029d786 + ?size param)

Method: Godot 4.7.2 Web export (single-thread), python http.server, Playwright + Chromium 1194,
ANGLE/SwiftShader (CPU GL), viewport 844x390, touch. No GPU, so FPS is a LOWER BOUND.

## Boot
- Boots OK; no console errors/warnings/pageerrors in any run (64 map, 250 map, DPR 1 and 3).
- Slow start in software GL (~25 s to first interactive frame at DPR 3).
- Added `?size=N` URL param (square map, clamp 32..512) in `# region W1` of view/game.gd; `?seed=` already existed.
  ?size=250 verified: starts and runs.

## Screenshots (dir: /tmp/claude-0/-home-user-colony-sim/2c9ef3d5-c73d-4d98-a862-7d15a0bb0a1a/scratchpad)
- w1_64_main.png (main view, DPR 3), w1_64_prepan.png / w1_64_postpan.png (pan + Orders panel open)
- w1_64_tap_b0..b9.png (toolbar taps), w1_d1_64_3x.png, w1_d1_250_3x.png, w1_d3_64_3x.png

## FPS (rAF counter, 10 s each; main thread ~100% busy = CPU-rendering bound)
| map | DPR | 1x | 3x |
|---|---|---|---|
| 64 | 3 (spec) | 0.9 (0.3 in first run) | 0.8 |
| 64 | 1 | 5.8 | 4.9 |
| 250 | 1 | 4.1 | 4.0 |

Longtask busy time is ~100-113% of wall time in all runs: frame time is dominated by SwiftShader
fill-rate (DPR 3 = 9x pixels, ~6x slower), not by sim ticks. 3x vs 1x barely changes FPS and
250 vs 64 costs only ~30%, so sim/map size is not the bottleneck here. Absolute numbers are
meaningless for real phones; a GPU device is needed.

## Functional checks
- Toolbar (Inspect/Zones/Build/Orders/Alarm, speed ||/1x/2x/3x/More) respond to taps; Orders opens a sub-panel.
- 3x tap registered (highlight; game clock advanced even at <1 FPS, so sim keeps up).
- One-finger drag pans the map (compare prepan/postpan).

## UI issues
- Orders sub-panel: colonist portrait column (left) overlaps the panel's first button (label clipped "...ча") at 844x390.
- Status line ("Заражение ... Твари спят · до «Осад...") is truncated with ellipsis beside the speed buttons.
- In-game text is Russian although the latest commit/CLAUDE.md says all in-game text should be English: verify.
- At DPR 1 content scale clamps to 1.0, so UI is small (desktop-ok, not a phone case); at DPR 3 buttons are comfortably large.
- On the 250 map the portrait column gets a scrollbar and the 4th portrait is hidden behind the bottom toolbar (scrollable).
