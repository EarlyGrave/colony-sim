# CLAUDE.md — project rules

Hobby colony sim ("RimWorld meets Factorio") on a prison planet. Core dilemma:
**mining is safe, refining is dangerous** — refining waste contaminates the
planet and provokes creature waves.

Every session starts by reading `CLAUDE.md`, `PROGRESS.md`, `DECISIONS.md`
and continues where the last one stopped.

## Stack
- Godot **4.7.2-stable**, GDScript only (no C#: we need the web build).
- Renderer: GL Compatibility. Web export is **single-threaded**
  (`variant/thread_support=false`) so GitHub Pages needs no COOP/COEP headers.
- Everything runs `--headless` in the cloud session; there is no GUI.

## Commands
```bash
godot --headless --path . --import                       # build .godot cache (needed once / after adding class_name)
godot --headless --path . res://tests/run_tests.tscn     # all tests
godot --headless --path . res://tests/run_tests.tscn -- --filter=test_map   # subset
godot --headless --path . --export-release "Web" build/web/index.html
```
Godot binary for a fresh cloud session: see README "Local setup".

## Architecture (hard rules)
- **Simulation is separate from the view.** `sim/` contains plain
  `RefCounted` classes with no rendering, no `Node`, no scene tree, no
  autoload lookups. `view/` only reads sim state and listens to the bus.
- **Fixed tick.** `Simulation.step()` advances one tick
  (`Simulation.TICKS_PER_SECOND` at 1x). The view (`GameController`) owns the
  speed (pause/1x/2x/3x) and calls `step()` as many times as needed.
- **Determinism.** All randomness goes through `sim.rng`
  (one seeded `RandomNumberGenerator`). Never use `randi()`, `randf()`,
  `Time`, or iteration over unordered sources in sim code. Same seed + same
  commands = same game.
- **Event bus.** `autoload/event_bus.gd` declares every cross-system signal.
  The game passes the `EventBus` autoload into `Simulation.new(seed, bus)`;
  tests pass a fresh instance (`TestCase.make_bus()`), so sims are isolated.
- **Data separate from logic.** Items, buildings, recipes, zones, enemies,
  job priorities and balance numbers live in `data/*.json` and are loaded by
  `Defs`. No gameplay numbers hard-coded in systems — add them to JSON.
- **Systems as modules**, one directory each under `sim/`:
  `core` (Simulation, Defs, Ledger), `map`, `colonists`, `jobs`, `items`,
  `buildings`, `contamination`, `threats`, `storyteller`.
  Systems talk via the bus or via `sim.<system>` references; keep the
  dependency direction simple (systems read the map/items, not the view).
- **Player commands** go through `Simulation` methods (`designate_mine`,
  `set_zone`, `place_building`, `set_alarm`…), never by poking system
  internals from the view. This keeps future replays/saves possible.

## Conventions
- Code, comments, commit messages: English. Reports to the owner: Russian.
- Static typing everywhere it is cheap (`var x: int`, typed arrays).
- Tabs for indentation (Godot default).
- Tests: `tests/test_*.gd`, extend `TestCase`, methods `test_*`.
  Every stage adds tests for its acceptance criteria.
- Small meaningful commits; push after each stage; **never push with failing tests.**
- UI is touch-first: big buttons (≥ 64 px), no hover, no right click,
  pan/zoom with fingers and mouse. Mouse events with
  `device == InputEvent.DEVICE_ID_EMULATION` are touch duplicates — ignore them
  in world input.

## Out of scope for now
Stress/breakdowns, factions, trade, roguelike meta, story, real art, sound.
Keep architecture open for them (new system dirs + bus signals), don't build them.
