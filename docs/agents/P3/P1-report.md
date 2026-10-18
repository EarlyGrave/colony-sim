# P3 report: creatures at scale

## Done
- `sim/map/flow_field.gd`: BFS distance field (8-neighbour, diagonals only if both orthogonals free), resumable
  (`expand(budget)`), step = neighbour with strictly lower distance.
- `Pathfinder`: walkability byte grid, `version` counter (bumped only when a cell's walkability really changes),
  `flow_cached/flow_to/advance_flows` (cache per key, dropped on version change, unbounded fields built
  incrementally at `flow_cells_per_tick`), counters `astar_calls`, `flow_builds`. Component labelling rewritten
  with flat ints (first-tick spike 600 ms -> ~70 ms on 250x250; also paid on every wall placement).
- `GridMover.move_flow`; enemies walk building targets / colonist chases (bounded field, `chase_flow_radius`)
  / leaving (4x4 block around spawn) on shared fields. No per-enemy A*.
- `sim/map/spatial_hash.gd`: enemies bucketed; turrets and `enemies_in_range` use it (same ordering as before:
  nearest first, ties by id; turret ties -> newest).
- Re-target stagger: next slot is `tick % retarget_ticks == id % retarget_ticks` (counter `retarget_count`).
  Enemies with NO target still re-choose every tick (changing that broke test_combat::order_move_and_attack timing).
- Enemy caches target refs (`target_b/target_c`, `attack_range`) instead of linear `get_by_id` per tick.
- balance.json `threat`: `hash_bucket`, `chase_flow_radius`, `flow_cells_per_tick`.

## Not done
- Colonists still use A* (out of scope). Colonist-aggro scan in `_choose_target` still loops all colonists/buildings.
- Map-size start option not present yet; measured with `start_empty(250,250)`.

## Numbers (`tools/perf_threat.gd`, 300 crawlers, 250x250, 600 ticks, ThreatSystem.tick only, headless CPU)
| | avg | steady p95 | max tick |
|---|---|---|---|
| before, 0 turrets | 3.46 ms | 5.20 ms | 666 ms |
| after, 0 turrets | 3.04 ms | 5.36 ms | 75 ms |
| before, 4 turrets | 3.69 ms | 5.64 ms | 704 ms |
| after, 4 turrets | 2.86 ms | 5.46 ms | 73 ms |

Caveat: the baseline already cached one A* path per enemy, so steady cost was similar; the gains are removal of the
~300-A* spike, no A* on retarget/chase, and cheap range queries. Avg meets <= 3 ms only marginally; p95 5.4 ms <= 8.

## Files / tests
sim/map/{flow_field,spatial_hash,pathfinder,grid_mover}.gd, sim/threats/{threat_system,enemy}.gd,
one-line hook in sim/buildings/building_system.gd `_evict`, data/balance.json, tools/perf_threat.gd,
tests/test_threat_scale.gd (6 tests). Full suite: 327 passed, 0 failed.

## Determinism / balance
Same seed gives the same game, but creature paths differ from A* (BFS tie-breaks), so balance_report numbers shift
per seed (chaotic); runs still end in the same outcome classes (hq_destroyed / colonists_dead / planet_dead) and
waves reach the colony. Existing combat/raid tests pass unchanged.
