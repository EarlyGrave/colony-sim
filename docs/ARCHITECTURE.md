# ARCHITECTURE — audit of the current code (E9)

Snapshot of what the code does today (not the plan). Source of truth is the code; rules live in `CLAUDE.md`.
Note: `CLAUDE.md` mentions `GameController`; the actual view entry point is `view/game.gd` (scene `view/game.tscn`).

## 1. Systems map

| dir | main classes | owns | reads from |
|---|---|---|---|
| `sim/core` | `Simulation`, `Defs`, `Ledger` | tick counter, `rng`, alarm, rules dict, game-over state, item ledger, all system references, bus connections (`listen`/`dispose`) | everything (it wires systems) |
| `sim/map` | `MapGrid`, `MapGenerator`, `Pathfinder`, `GridMover` | tiles, mine designations, zone ids per cell (emits tile/designation/zone signals); A* grid + connected components; seeded generation | `bus` (listens `tile_changed` -> `Pathfinder.refresh_cell`); `rng` only passed in by Simulation |
| `sim/items` | `ItemSystem` | one stack per cell, storage zones, `drop()` spill, `count_world` (conservation) | `map`, `defs`, `ledger` ("lost" sink) |
| `sim/colonists` | `Colonist`, `ColonistSystem` | colonist list/state, movement, death; `spawn()` | `rng` (names), `jobs`, `map`, `threats` |
| `sim/jobs` | `JobSystem`, `Job` + `MineJob`/`HaulJob`/`OperateJob`/`RepairJob`/`FleeJob` | job selection (work-giver by priority from `data/jobs.json`), string-key reservations, flee override on alarm | `map`, `items`, `buildings`, `pathfinder`, `threats`, `defs`; emits `item_mined` (MineJob); `ledger` ("mining") |
| `sim/buildings` | `Building`, `BuildingSystem` | placement/validation, cost payment, recipes (batches), wear/broken, damage/destroy (buffers spill) | `items`, `map`, `defs`, `ledger` ("construction", "recipe") |
| `sim/contamination` | `ContaminationSystem`, `ForecastModel` | planet contamination level + rate, forecast of the end, waste emission by zone | `items` (waste on ground), `defs`; listens `batch_refined`, `first_refine_done` |
| `sim/threats` | `ThreatSystem`, `Enemy` | awakening, waves, enemies, turret fire, targeting | `buildings`, `colonists`, `ledger` counts (`mining:essence_ore`, `recipe:refined_essence`), `contamination`, `rng`; listens `first_refine_done`, `item_mined` |
| `sim/storyteller` | `Storyteller` | event schedule, one broken link at a time | `rng`, `buildings`, `colonists`, `threats`; listens `first_refine_done`, `threat_awakened`, `wave_started`, `building_broken` |
| `view` | `game.gd` (Game), `WorldView`, `CameraController`, `Hud` | speed, tick accumulator, input, rendering | sim state (polling); bus: `tile_changed`, `enemy_killed`, `story_event`, `game_over` |
| `autoload` | `event_bus.gd` | signals only | - |

Wiring: `Simulation._init_systems()` builds `pathfinder, items, colonists, buildings, jobs, contamination, threats, storyteller`; every system gets the `Simulation` (`sim`) and reaches peers through `sim.<system>` (back-references, cycles broken in `dispose()`).

## 2. Tick order

`Game._process` (view/game.gd) is the only production caller of `Simulation.step()`: it accumulates `delta * TICKS_PER_SECOND (10) * speed` (speed 0/1/2/3, capped by `MAX_TICKS_PER_FRAME`) and calls `sim.step()` n times. Tests and `tools/balance_report.gd` use `run_ticks(n)`.

`step()` order: return if game over -> `tick += 1` -> `colonists.tick()` (JobSystem decides inside) -> `threats.tick()` -> `contamination.tick()` -> `storyteller.tick()` -> game-over check (all colonists dead) -> `day_started` (if `tick % ticks_per_day == 0`) -> `tick_advanced`. `BuildingSystem` and `JobSystem` have no own `tick()`: they are driven from jobs/colonists.

## 3. EventBus signals (`autoload/event_bus.gd`)

| signal(args) | emitted by | listened by (sim/view) |
|---|---|---|
| `tick_advanced(tick)` | Simulation.step | - |
| `day_started(day)` | Simulation.step | - |
| `tile_changed(cell)` | MapGrid | Simulation (Pathfinder.refresh_cell), WorldView |
| `designation_changed(cell)` | MapGrid | - |
| `zone_changed(cell)` | MapGrid | - |
| `item_mined(cell, item_id, amount)` | MineJob | ThreatSystem |
| `building_placed(id)` | BuildingSystem | - |
| `building_destroyed(id)` | BuildingSystem | - |
| `building_broken(id)` | BuildingSystem | Storyteller |
| `building_repaired(id)` | BuildingSystem | - |
| `batch_refined(building_id, recipe_id)` | BuildingSystem | ContaminationSystem |
| `first_refine_done()` | BuildingSystem | ContaminationSystem, ThreatSystem, Storyteller |
| `contamination_changed(level)` | ContaminationSystem | - |
| `forecast_revealed()` | ContaminationSystem | - |
| `threat_awakened()` | ThreatSystem | Storyteller |
| `wave_started(index, strength)` | ThreatSystem | Storyteller |
| `wave_ended(index)` | ThreatSystem | - |
| `enemy_killed(enemy_id)` | ThreatSystem | WorldView |
| `colonist_died(colonist_id)` | ColonistSystem | - |
| `alarm_changed(active)` | Simulation.set_alarm | - |
| `rule_changed(rule_id, on)` | Simulation.set_rule | - |
| `game_over(reason)` | Simulation.end_game | Game (HUD) |
| `story_event(event_id, text)` | Storyteller | Game (HUD message) |

Signals without any sim/view listener today are free extension hooks (HUD polls state instead). Sim-side subscriptions must go through `Simulation.listen()` so `dispose()` can undo them.

## 4. Player commands (`Simulation`)

| method | effect |
|---|---|
| `start_new_game()` / `start_empty(w, h)` | generate map + colony / empty test map |
| `designate_mine(cell, on)` | mine designation on `MapGrid` |
| `set_zone(cell, zone_id)` -> bool | storage zone ("" clears) |
| `can_place_building(def_id, cell)` -> String (error or "") | placement check |
| `place_building(def_id, cell)` -> Building or null | pays cost, places |
| `set_rule(rule_id, on)` / `is_rule_on(rule_id)` | player rules (`data/rules.json`) |
| `set_alarm(on)` | flee override for colonists |
| `end_game(reason)`, `run_ticks(n)`, `step()` | flow control |
| helpers: `day()`, `map_center()`, `cell_free_for_items(c)`, `listen(sig, cb)`, `dispose()` | |

Not yet a command (view/jobs touch internals or no UI): repair priority, colonist job priorities, demolish, haul/zone assignment per building.

## 5. Data files

All loaded once by `Defs.load_from(dir)` (default `res://data/` via `Defs.get_default()`; `duplicate_defs()` for tests). No other class reads JSON.

| file | `Defs` field | used by |
|---|---|---|
| `items.json` | `items` | ItemSystem (`item_stack`), jobs, view |
| `buildings.json` | `buildings` | BuildingSystem, Simulation.can_place_building, view |
| `recipes.json` | `recipes` | BuildingSystem |
| `zones.json` | `zones` | ItemSystem, `zone_accepts`, ContaminationSystem (emission) |
| `enemies.json` | `enemies` | ThreatSystem, Enemy |
| `jobs.json` | `jobs` | JobSystem (`job_priority`) |
| `balance.json` | `balance` (`bal(section,key)`) | Simulation (map, colony, ticks_per_day), Threat/Contamination/Storyteller |
| `events.json` | `events` | Storyteller |
| `rules.json` | `rules` | Simulation (defaults), JobSystem/ThreatSystem via `is_rule_on` |

## 6. Determinism as implemented

- One `RandomNumberGenerator` `sim.rng`, seeded in `Simulation._init`. Consumers: MapGenerator (receives it as an argument), ColonistSystem (names), ThreatSystem (wave composition, spawn edge/cell), Storyteller (chance, weighted roll, targets).
- Order of draws depends on tick order (colonists -> threats -> contamination -> storyteller) and on the order of game start; adding a draw anywhere shifts all later results, so new randomness must go through `sim.rng` at a fixed place.
- Ledger: `record_produced(item, n, source)` / `record_consumed(item, n, sink)`; invariant `world == produced - consumed`. Sources today: `start`, `mining`, `recipe`; sinks: `construction`, `recipe`, `lost`. ThreatSystem reads ledger counts as inputs of wave strength (so ledger keys are part of the balance contract).
- Rule from `CLAUDE.md` (no `randi()/randf()/Time`, no unordered iteration): ItemSystem zone cells are insertion-ordered dictionaries; the audit did not grep every `for k in dict` in sim (open item).

## 7. Extension points for E10–E22

| future | where | how |
|---|---|---|
| Inventory / carried items | `sim/items` + `sim/colonists` | extend `ItemSystem.count_world` and Ledger sinks; new signals `item_*` on bus |
| Production / power / logistics | `sim/buildings` (+ new `sim/power`, `sim/logistics`) | recipes in `data/recipes.json`; new system created in `Simulation._init_systems`, ticked in `step()` after colonists; signals `power_changed`, `batch_*` on bus |
| Combat | `sim/threats` (split `sim/combat` if it grows) | weapons/turrets in `data/enemies.json` + `buildings.json`; keep `enemy_killed`, add `colonist_hurt` |
| Research | new `sim/research` | `data/research.json` via `Defs`; gates `can_place_building`; signals `research_started/finished` |
| Story / events | `sim/storyteller` | add entries to `data/events.json`; story text through `story_event` |
| Save / load | `sim/core` | serialize via `Simulation` state + seed + command log (all commands already go through `Simulation`); needs `to_dict/from_dict` per system (not present yet) |
