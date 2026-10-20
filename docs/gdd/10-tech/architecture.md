# Architecture summary (designer-facing)

## Hard rules (CLAUDE.md) `[BUILT]`
1. **Sim is separate from the view.** `sim/` = plain `RefCounted`, no Node/scene/autoload lookups; `view/`
   only reads sim state and listens to the bus.
2. **Fixed tick.** `Simulation.step()` advances one tick (10/s at 1x, 600 ticks/day); the view owns speed.
3. **Determinism.** One seeded `sim.rng` (PCG32) plus named sub-streams (debt, idle_work, mutation, ecology,
   storyteller chain, affix child rng); never `randi()`/`Time`/unordered iteration. Same seed + same command
   log = same `state_hash` every tick. 8 golden replays (`tests/golden/*.json`, incl. 3 presets, save/load
   midgame); `tools/make_golden.gd --regen` only for an INTENDED sim change.
4. **Event bus** (`autoload/event_bus.gd`, ~70 signals) injected into `Simulation.new(seed, bus, defs, opts)`;
   tests use a fresh bus.
5. **Data separate from logic.** All numbers in `data/*.json` (loaded once by `Defs`); tests must not
   mutate the shared `Defs.get_default()`.
6. **Player commands** only through `Simulation` methods, recorded as `[tick, name, args]` for replay/save
   (~65 commands; table in `docs/sim_contract.md §4`).

## Tick order (`Simulation.step()`)
crafting -> needs -> farming -> colonists (jobs, movement) -> logistics (belts) -> power + machines ->
chips -> perks -> health -> debt -> mood -> threats -> contamination -> mutation -> ecology -> crises ->
regulations -> storyteller; then game-over check, `day_started`, `tick_advanced`.

## Systems (one directory each under `sim/`)
core (Simulation, Defs, Ledger, SaveGame, perk hooks) · map · items · colonists (+ skills, traits,
generator, records) · jobs (work givers + jobs) · buildings (+ blueprints, decoys) · crafting (bills, storage
settings) · logistics (belts, ports, nodes) · automation (chips) · power · research (+ milestones,
petitions, operator) · contamination · mutation · ecology · threats (+ metro track, raid objectives, threat
model) · combat · equipment · squads · health · needs · farming · mood · debt (+ beacons) · contracts ·
crises · storyteller · quests (+ q1) · society · regulations · fixation · endings · shuttle · meta ·
campaign · tutorial · idle_work · perks · progression · quality · world (clock).

## View
`view/game.gd` (GameController: seed, speed, input -> commands, NG+, meta), `hud.gd`, `world_view.gd` +
`world_3d.gd` (pseudo-3D), `camera_controller.gd`, `panels/*`, `feed_director.gd`/`pa_banner.gd`
(narrative surface), `save_store.gd`/`meta_store.gd` (browser storage), `flavor_picker.gd`.

## Save / replay `[BUILT]`
Save = seed + opts + command log (+ campaign v3); load replays; autosave daily in the browser; `state_hash`
parts join only when a system has state (tutorial, equipment, suspicion...), so goldens stay stable.

## Budgets
Sim: 300 enemies at 250x250 ~2.1 ms/tick desktop (budget 2.0, open); total 4 ms / p95 10 ms; combat
bucket 0.66 ms with 224 fully equipped inmates; web wasm ~2-3x slower, single-threaded. Memory 69-87 MB
static at 250. `tests/perf_budget.json` (x1.5 tolerance, `PERF_SKIP_WALL` in shards).

## Stack and build
Godot 4.7.2-stable, GDScript only (no C#: web build), GL Compatibility, web export single-threaded
(`variant/thread_support=false`, no COOP/COEP), CI tests + export on every push, Pages deploy from `main`.
Host: 4 cores, <= 5 workers; workers run quick tests only; full sharded suite before main.
