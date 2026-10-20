# Touch rules and the view

## Hard rules `[BUILT]` (CLAUDE.md conventions, D13, D14)
- Touch-first: buttons >= 64 px physical, no hover, no right click, no drag-to-order (rect tools = two
  taps so dragging always pans). Long-press opens a radial menu (mine / zone / build / belt / inspect,
  + 3 machines, avoids the belt strip).
- Stretch mode `disabled`, `content_scale_factor = devicePixelRatio x 0.85` (min 1) in
  `GameController._apply_ui_scale` so buttons keep physical size on phones.
- `emulate_mouse_from_touch = true`: one finger = emulated mouse (HUD + world tap/pan), pinch = raw
  `InputEventScreenDrag`; mouse events with `device == DEVICE_ID_EMULATION` are ignored in world input.
- One number per decision, cost quoted in the hint (quest options, regulations, petitions).
- All text English (owner 2026-10-18); <= 70 chars per line for story text.

## Pseudo-3D view `[BUILT]` — `view/world_view.gd`, `world_3d.gd`, `chunk_layer.gd`, `unit_layer.gd`, `belt_layer.gd`, `power_layer.gd`, `effects_3d.gd`, `building_3d.gd`
Flat layers paint into a SubViewport at 16 px/cell; a tilted perspective Camera3D (52 deg, looks north)
shows it as a ground plane; rock/ore/walls/machines are raised blocks (MultiMesh, voxel `data/models.json`,
`FLAT_FALLBACK` for new buildings); units are MultiMesh billboards with walk sheets (`tools/gen_art.py`,
all art generated, D19). Camera: pan/pinch/wheel keep the ground point under the finger, inertia, clamps.
Juice (`data/fx.json`): death bursts, splats, sludge drips, "AUDITED" label, tracers, smoke; world tints
green with contamination; dump zone tint + legend (F7). Night tint from the day clock.
Perf: dirty-chunk redraws, lazy chunks (static memory 69 MB at 250x250), HUD throttled to 10 Hz,
unit script 0.6-0.9 ms/frame. Real phone frame time never measured (cloud has software GL only).

## Screenshots and smoke `[BUILT]`
`xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn -- --out=shot.png`;
`tools/web_smoke.py` (Playwright, 844x390 DPR3 touch: boot, console errors, toolbar taps, `?size=250`,
FPS/memory — jsheap ~150 MB, watch). Web URL params: `?seed=N`, `?size=N`.

## Known UI debts
No scrim behind some sheets is fixed (Y5); win screen contrast fixed (U3); quest sheet vs notification
stack overlap handled (R5); belt reachable from Build popup (Y5). Open: HUD covers much of the world during
a siege on a phone; no HUD surface for scent/dormancy beyond the ticker.
