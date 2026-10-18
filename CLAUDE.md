# CLAUDE.md — project rules

Hobby colony sim ("RimWorld meets Factorio") on a prison planet. Core dilemma:
**mining is safe, refining is dangerous** — refining waste contaminates the
planet and provokes creature waves.

Every session starts by reading `CLAUDE.md`, `PROGRESS.md`, `DECISIONS.md`
and continues where the last one stopped.

## Working mode: orchestrator + prompter + workers (owner rule, mandatory)
At every session start or restart, after reading the docs above, work in this
mode — the main session does NOT implement features itself:
1. **Orchestrator** (main session): talks to the owner (in Russian), picks the
   batch, merges worker branches, runs the full test suite, takes a screenshot
   for visual work, updates `PROGRESS.md`/`DECISIONS.md`, commits and pushes.
   Only tiny fixes (merge conflicts, a red test after a merge, docs) by hand.
2. **Prompter** (one subagent, Sonnet): turns the owner's request into a plan
   file `docs/<batch>_plan.md` (≤ 60 lines): one wave of 3–5 parallel workers,
   disjoint file ownership, acceptance criteria, tests. Plans only, no code.
3. **Workers** (subagents, Sonnet, `isolation: worktree`, run in background):
   each does exactly its plan section. Rules: start with
   `git reset --hard claude/colony-sim-godot-4jftsm`; shared files only inside
   `# region <agent>` blocks; `sim/` stays deterministic; all tests green;
   commit in the worktree, never push; report ≤ 30 lines in
   `docs/agents/<agent>/<batch>-report.md`.
4. **Mechanics scout** (subagent, Sonnet, read-only + one doc): call it when ideas run
   out or before planning a new batch. It studies neighbour games (colony sims,
   factory games, roguelikes, survival, strategy…), picks mechanics that fit our
   pillars, REWORKS them so they are not direct copies (new twist tied to the prison
   planet / essence / contamination), and writes `docs/scout/<topic>.md` (≤ 80 lines:
   source inspiration, our version, why it fits, cost S/M/L). It must load WebSearch/
   WebFetch via ToolSearch and check facts live. Its output goes to the
   game designer and the prompter, never straight to workers.
5. Budget: one wave per batch, Sonnet for subagents, the orchestrator does not
   re-read files the agents already read; short reports.
6. **Merge to `main`** (owner rule 2026-10-18): when a whole batch is merged into the
   dev branch and the full suite is green, fast-forward/merge it into `main` and push
   (Pages deploys from `main`). Never merge a half-done batch.
7. **Autonomous mode** (owner rule 2026-10-18): the orchestrator keeps a 5-minute
   self check-in (`send_later`). On each check-in: if workers are still running,
   re-arm and wait; if everything is merged, nothing is pending and the owner has
   not written, call the mechanics scout -> hand its ideas to the prompter -> run
   the next wave. Undecided design questions: decide, log in DECISIONS.md as
   "decided without owner, review", keep it reversible. Never stop the loop just
   because a batch ended.
8. Visual checks: `xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn -- --out=<scratchpad>/shot.png`.

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
tools/run_tests_sharded.sh 4                              # full suite as 4 parallel shards (~2 min; sets PERF_SKIP_WALL=1, run test_perf_budget single-process)
godot --headless --path . --export-release "Web" build/web/index.html
PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers python3 tools/web_smoke.py   # web smoke: export+serve, 844x390 DPR3 touch, boot, console errors, toolbar taps, ?size=250, FPS/mem, screenshots (pip install playwright==1.56.0; NEVER `playwright install`)
godot --headless --path . -s tools/mem_probe.gd -- --size=250   # static memory + VRAM estimate of the map view
godot --headless --path . -s tools/make_golden.gd -- --regen   # regenerate tests/golden/*.json after an INTENDED sim/balance change (prints changed ticks)
```
Godot binary for a fresh cloud session: see README "Local setup".

## Architecture (hard rules)
- **Simulation is separate from the view.** `sim/` contains plain
  `RefCounted` classes with no rendering, no `Node`, no scene tree, no
  autoload lookups. `view/` only reads sim state and listens to the bus.
- **Fixed tick.** `Simulation.step()` advances one tick
  (`Simulation.TICKS_PER_SECOND` at 1x). The view (`GameController`, file `view/game.gd`) owns the
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

## Layout of systems
| dir | main classes | notes |
|---|---|---|
| `sim/core` | `Simulation`, `Defs`, `Ledger` | tick order: colonists → threats → contamination → storyteller |
| `sim/map` | `MapGrid`, `MapGenerator`, `Pathfinder`, `GridMover` | AStarGrid2D + connected components for O(1) reachability |
| `sim/items` | `ItemSystem` | one stack per cell; zones = storage; `drop()` spills, records "lost" if no room |
| `sim/colonists` | `Colonist`, `ColonistSystem` | |
| `sim/jobs` | `JobSystem` + `*Job` | work-giver style; reservations by string key; flee overrides on alarm |
| `sim/buildings` | `Building`, `BuildingSystem` | recipes, wear/broken, damage/destroy (buffers spill) |
| `sim/contamination` | `ContaminationSystem`, `ForecastModel` | |
| `sim/threats` | `ThreatSystem`, `Enemy` | waves, targeting, turrets |
| `sim/storyteller` | `Storyteller` | events from data/events.json, one broken link at a time |
| `view` | `GameController` (`view/game.gd`), `WorldView`, `WorldView3D`, `CameraController`, `Hud` | pseudo-3D: `WorldView` paints flat layers into `MapViewport` (16 px/cell); `WorldView3D` shows it as a ground plane + rock/wall blocks + standing unit sprites; `CameraController` is a tilted perspective Camera3D (API in 2D world px). Screenshot: `xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn -- --out=shot.png`; sprites from `assets/sprites/` (generated by `tools/gen_art.py`) |

Balance numbers: `data/balance.json`. Player rules: `data/rules.json` +
`Simulation.set_rule()`. Storyteller events: `data/events.json`. `tools/balance_report.gd` prints wave
outcomes for several seeds (`godot --headless --path . -s tools/balance_report.gd`).
Shared test scenarios: `tests/scenario.gd`.

## Conventions
- Code, comments, commit messages: English. Reports to the owner: Russian.
- **All in-game text is English** (UI, letters, hints, names in `data/*.json`) — owner rule 2026-10-18.
- Static typing everywhere it is cheap (`var x: int`, typed arrays).
- Tabs for indentation (Godot default).
- Tests: `tests/test_*.gd`, extend `TestCase`, methods `test_*`.
  Every stage adds tests for its acceptance criteria. Use `make_sim()`
  (auto-disposed) and `peaceful_defs()` when a test is not about creatures.
  The runner fails a test on ANY engine/script error (custom `Logger`).
- Small meaningful commits; **commit and push after every significant change** (each merged agent branch, balance pass, doc update) — owner request; **never push with failing tests.**
- UI scale: stretch mode "disabled" + `content_scale_factor = devicePixelRatio * 0.85`
  (set in `GameController._apply_ui_scale`), so buttons keep physical size on phones.
- UI is touch-first: big buttons (≥ 64 px), no hover, no right click,
  pan/zoom with fingers and mouse. Mouse events with
  `device == InputEvent.DEVICE_ID_EMULATION` are touch duplicates — ignore them
  in world input.

## Out of scope for now
Stress/breakdowns, factions, trade, roguelike meta, story, real art, sound.
Keep architecture open for them (new system dirs + bus signals), don't build them.
