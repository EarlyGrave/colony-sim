# DECISIONS.md — significant decisions

Format: what was chosen · why · alternatives.

## D1. Godot 4.7.2 + GDScript instead of the TypeScript engine from the design doc
The design doc mentions a custom TypeScript engine + Tauri/Electron. The
kick-off prompt (newer, more specific) demands Godot + GDScript with a web
build. Followed the prompt. Web export still gives an itch.io / iPad-webview
path. Alternatives: custom TS engine (more work, no editor), C# (no web export).

## D2. Own minimal test runner instead of GUT
`tests/test_runner.gd` (≈60 lines) + `TestCase` base. No addon download,
no version drift with Godot 4.7, trivially headless, exit code for CI.
Alternative: GUT — richer but heavier and pinned to Godot versions.

## D3. Event bus: autoload script, injected instance
The prompt asks for an autoload with signals. Sim code receives the bus as a
constructor argument instead of referencing the `EventBus` singleton, so
tests can create isolated bus instances (`EventBusScript.new()`) and run
several simulations without cross-talk. The game passes the real autoload.

## D4. CI deploys only from `main`
Tests + web export run on every push to any branch; Pages deploy only from
`main` (as the prompt specifies). Work branches therefore don't change the
public build until merged.

## D5. Data in JSON, not .tres
`data/*.json` + `Defs` loader. Easy to edit/diff without the editor (we have
no GUI), trivially duplicated for test scenarios (`duplicate_defs()`).
Alternative: `.tres` Resources — typed, but awkward to author headless.

## D6. Jobs are generated on demand ("work givers"), not queued
Idle colonist asks providers in priority order (data/jobs.json), nearest
candidate wins; targets are reserved by string keys. No stale global queue to
keep in sync with the world. Alternative: persistent job queue — needs
invalidation on every world change.

## D7. Items are discrete stacks with a Ledger
One stack per cell, carried stacks, building buffers. Every creation /
destruction goes through `Ledger`, so "nothing appears or vanishes" is a
testable invariant (`count_world == produced - consumed`).

## D8. Buildings are walkable; deposits and rock are solid
Simplifies pathing (no footprint re-solving); workers stand on the building's
top-left cell. Deposits are mined from an adjacent cell.

## D9. "Склад" as an enemy target = the capsule
Storage is player-painted zones (per E3), zones have no HP. Enemies target
buildings by `threat_priority`: refinery (3) > capsule/HQ (2) > turret (1),
and turrets nearby / colonists in the open take precedence. The capsule
(starting HQ) is the shelter; losing it ends the game. Alternative: a storage
building with HP — would duplicate storage logic; can be added later.

## D10. Waves end on a timer; survivors retreat
A wave lasts `wave_duration_ticks`, then remaining creatures walk back to the
edge. Without this an undefended colony would be wiped on wave 1, which
contradicts "without turrets you fall on wave 2–3".

## D11. Wave balance targets (fixed-seed tests)
No turrets: colony falls on wave 2–3. Three static turrets: holds 3 waves,
falls on 4 (growth outpaces static defense = "needs intervention"). Player
rebuilding/adding turrets between waves: seed 1 survives 8 waves. Numbers in
`data/balance.json` "threat"; `tools/balance_report.gd` to re-check.

## D12. Repairs restore both HP and condition, cost nothing (for now)
Machines get repaired pre-emptively below 50% condition (data). Breakdowns
mostly happen under load during waves, when colonists hide. Later: repair
materials, maintenance rules.

## D13. Touch input: emulated mouse for one finger, raw touch for pinch
`emulate_mouse_from_touch=true` so HUD buttons work by touch and swallow
taps; world pan/tap uses (emulated) mouse in `_unhandled_input`, pinch uses
raw `InputEventScreenDrag`. Rect tools (zones, mining) use two taps instead of
drag, so dragging always pans.

## D14. UI scale from devicePixelRatio
Stretch mode `disabled`, `content_scale_factor = dpr * 0.85` (min 1). A fixed
1280×720 canvas_items base made buttons ~22 CSS px on a portrait phone.
