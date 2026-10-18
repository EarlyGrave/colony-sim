# Optimization strategy (consultant report, 2026-10-18, read-only audit)

Scope: Godot 4.7.2 GDScript, GL Compatibility, single-threaded wasm on phones, 10 ticks/s x3, 250x250 maps, ~300 creatures,
belts, multi-map campaign. Measured on the cloud box (4 vCPU, software GL). Budgets from docs/perf_batch_plan.md:
sim <= 3 ms/tick desktop (~10 ms wasm), view <= 16 ms/frame.

## 1. Baseline (this session, `tools/perf_bench.tscn`, 600 ticks, seed 1; ms/tick avg / p95)
| map | enemies | buildings | colonists | threats | contam. | mutation | total |
|---|---|---|---|---|---|---|---|
| 64 | 0 | 0.02/0.03 | 0.07/0.34 | 0.00 | 0.02 | 0.08/1.47 | 0.21/1.58 |
| 64 | 300 | 0.01 | 0.04/0.20 | 1.61/2.38 | 0.02 | 0.09/1.56 | 1.78/3.13 |
| 250 | 0 | 0.02 | 0.07/0.31 | 0.00 | 0.02 | 0.01/0.02 | 0.13/0.37 |
| 250 | 300 | 0.03/0.07 | 0.14/0.42 | 2.23/4.40 | 0.03 | 0.01/0.02 | 2.44/4.72 |

Caveats and extra measurements:
- The bench mirrors an **old** `step()`: it skips logistics, tick_machines, chips, abilities, squads, ecology, militia, tutorial
  (`tools/perf_bench.gd:35-55` vs `sim/core/simulation.gd:369-401`). With 300 enemies the 4 colonists die in the first ticks,
  so "colonists/jobs" is measured on an empty colony. A real 64x64 bot colony (8 colonists, `tools/bot_report.gd --days=5`)
  runs 3000 ticks in ~2.4 s wall = **~0.8 ms/tick all systems**. `tools/perf_threat.gd`: 300 enemies / 250 map = 3.17 avg, p95 5.9,
  max 77 ms (first-tick flow builds), astar_calls = 20.
- **Full `step()` with belts (scratch script, 250 map, 300 enemies, 8.5k belt cells, 2.8k items on belts): logistics 7.7 / 11.8 ms,
  threats 58.7 / 135 ms, total 66.8 / 144 ms.** Bisect: `threat.base.belt = 0` -> threats 3.5 ms. Cause: `ThreatModel.pick`
  (`sim/threats/threat_model.gd:207`) scores every candidate per retargeting enemy; belts add one candidate per 8x8 region
  (~600), 300 enemies / 20 ticks -> ~9k `score()` calls/tick at ~4 us each. This is the real cliff for the factory mid-game.
- `BeltGrid.step` (`sim/logistics/belt_grid.gd:186`) walks all `width*height` cells twice per tick whenever one item exists
  (62.5k cells at 250) and allocates 3 PackedInt32Arrays per tick.
- View under xvfb (software GL, suggestive only): 250 map + 300 enemies 81 ms/frame p95 100; 64 map, 0 enemies 60 ms/frame.
  Per-frame work found by reading: `WorldView._process` calls `queue_redraw()` every frame and `_draw` re-issues the whole
  map (zones, field, items, buildings, colonists, enemies) into every active chunk SubViewport (`UPDATE_ALWAYS`,
  `view/chunk_layer.gd:115`); `World3D._process` builds `"c%d"/"e%d"` string keys and a `seen` Dictionary per unit per frame,
  sets ~8 Sprite3D properties per unit (each a RenderingServer call), `_walls_signatures()` scans all buildings per frame,
  shadows MultiMesh re-uploaded per frame; `Hud._process` recomputes `count_stored/count_world` (full stack scans) and rewrites
  5 Label texts every frame (`view/hud.gd:642`); `BeltLayer.sync` compares the full `dir` array and re-fills item MultiMeshes of
  every visible chunk each frame.
- Sim code smells: `enemies.duplicate()` and `buildings.list.duplicate()` every tick (`threat_system.gd:180,520`); `has_meta/get_meta`
  string-keyed per enemy per tick (`:395,:695`); `sim.get_rule_mode()` string compare per turret per tick; `FlowField.build`
  allocates and fills a full-map `dist` array even for radius-16 chase fields, and the cache drops **all** fields at 48 entries
  or on any `Pathfinder.version` bump (`pathfinder.gd:196-211`); `SpatialHash` keys by `get_instance_id()` through two
  Dictionaries and `Array.erase` (`spatial_hash.gd`); `belts.hp_dirty` is only cleared by the view, so it grows forever headless /
  on autopilot maps; job givers rescan `items.stacks` and `buildings.list` per idle colonist and format `"rep:%d"`/`"dst:%d,%d"`
  reservation strings; `ColonistSystem.get_by_id` is linear and called from squads/abilities each tick; `state_hash` is
  `var_to_str(parts).hash()` (fine for tests, too slow for a per-tick hash).
- Test suite: 594 tests, ~5.5 min wall, single process. Top files: test_qa_longrun 60 s (one test 38 s), test_qa_tutorial 31 s,
  test_long_sim 16 s, event_chains/campaign/contracts/golden ~10 s each. Everything else is < 1 s per test.

## 2. Ranked opportunities (gain = at the measured scale; risk = determinism/goldens; effort S/M/L)
1. **Threat targeting cache per region** — `threat_model.gd pick/score`: precompute candidate list + value per 8x8 region once per
   `recompute_ticks`, score only the K nearest regions (spatial bucket walk) and collapse belts into their region entry; keep tie
   order (index order). Gain: threats 58 -> ~4 ms with belts, 2.2 -> ~1.2 without. Risk: medium (target choice may change where
   candidates are far; verify with goldens `raid_turrets`, `automation_chain`). Effort M.
2. **Sparse belt stepping** — `belt_grid.gd step`: keep a PackedInt32Array of occupied belt indices (maintained in insert/take/
   _resolve) and reuse the movers/carried/targets buffers. Gain: 7.7 -> <0.5 ms at 8.5k belts. Risk: none if move order stays
   index-ascending (sort the sparse list or keep it sorted by insertion = index order). Effort S.
3. **Bounded flow fields without full-map arrays** — `flow_field.gd build`: window the `dist` array to the bounded box (or use a
   per-field Dictionary-free offset grid); replace clear-all eviction with LRU per key and partial invalidation (only fields whose
   bbox touches the changed cell). Gain: removes the 77 ms first-tick spike and the rebuild storms after every wall/door/mined
   rock; -30% threats avg. Risk: low (same distances). Effort M.
4. **Data-oriented Enemy (SoA)** — `enemy.gd` fields -> PackedInt32/Float32 arrays in ThreatSystem (cell, hp, target, cds); keep
   `Enemy` as a thin handle for view/tests. Gain: ~2x on the per-enemy loop, no `duplicate()`, no meta lookups (replace `has_meta
   ("tg")`/`"bite_cd"` by two packed arrays). Risk: medium (golden "parts" dump script properties; keep a compat `to_dict`). Effort L.
5. **Tick-rate tiers (LOD) for creatures** — enemies farther than N cells from any colonist/building/turret and not in a
   wind-up run their `_tick_enemy` every 2nd/4th tick with `move_t` catch-up; stagger by `id`. Gain: 40-60% threats in the
   approach phase. Risk: **high** for goldens (movement timing changes) -> regenerate goldens intentionally, keep `balance.json
   threat.lod_enabled=false` for old replays. Effort M.
6. **View: creatures and colonists as MultiMesh + GPU animation** — one MultiMesh per sheet (colonist/crawler/brute...), custom
   data = frame row/col/flip/tint, shader picks the frame from `TIME` and a per-instance phase; move lerp on GPU from (cell,
   next_cell, move_t). Replaces ~300 Sprite3D (8 property sets each per frame) by one buffer upload. Gain: view -40 ms at 300 units
   on the software box; real phone likely 2-3x fewer draw calls. Risk: none to sim. Effort L.
7. **Stop redrawing the ground every frame** — `world_view.gd:165`: only `queue_redraw()` when a dirty flag is set by bus events
   (tile/zone/item/building changes) and move moving things (colonists, enemies, shots, particles) out of the chunk viewports into
   the 3D layer (they already are drawn there). Then set chunk viewports to `UPDATE_ONCE` on dirty. Gain: the biggest single view
   win for 64x64 too (60 ms/frame headless is mostly this). Risk: none. Effort M.
8. **HUD at tick rate, not frame rate** — `hud.gd _process`: update texts on `tick_advanced` every 5 ticks or on the relevant bus
   signals; cache `count_stored` per item in ItemSystem (incremental counters updated in add_at/take_at/set_zone). Gain: 1-3 ms/
   frame on phones (Label re-layout is costly on GL Compat) + removes 2 full stack scans per frame. Risk: none. Effort S.
9. **String-key elimination in the view** — `world_3d.gd`: index units by int id in two Dictionaries (or arrays), drop the `seen`
   dict, update `_wall_keys` from `building_placed/destroyed` signals instead of `_walls_signatures()` per frame. Gain: ~1 ms/frame
   at 300 units, fewer allocations/GC. Risk: none. Effort S.
10. **Job scan caching** (plan P5, still open) — `job_system.gd assign` + givers: maintain candidate sets (haulable stacks, mine
    designations, build sites, machines needing input) updated by bus events; reserve by int keys (`(kind<<32)|id`) instead of
    formatted strings; stagger `assign` by `colonist.id % k`. Gain: colonists 0.14 -> ~0.05 ms now, but it is what scales with 20+
    colonists on 250 maps. Risk: medium (assignment order must stay identical: iterate caches in the same order as the scan).
    Effort M.
11. **SpatialHash on packed buckets** — index by enemy int id, bucket = fixed grid array of PackedInt32Array (no Dictionary, no
    `erase`), query writes into a reusable array. Gain: ~15% threats. Risk: query order must stay bucket-major then insertion. Effort S.
12. **Batch bus signals** — `contamination_changed` every 10 ticks is fine, but `item_mined`/`tile_changed`/`belt_*` fire per event
    and the view redraws per signal; coalesce into per-tick dirty sets (`bus.tick_advanced` consumers read sets). Gain: removes
    signal storms during mining/raids (p95). Risk: none. Effort S.
13. **Mutation/contamination field: event-driven sleep** — `mutation_system.gd` already slices; add "no active sources and field below
    eps -> skip diffusion" and a per-row activity mask (partly present `_act_cur`). Gain: p95 1.5 ms spikes at 64 maps vanish.
    Risk: none if the sleeping state is exactly zero. Effort S.
14. **Memory/GC churn** — `FlowField` 250 KB per field x 48, 64 SubViewports x 512x512 RGBA (64 MB VRAM at 250 maps!),
    `shots`/`_fx` arrays of arrays, per-tick Packed arrays. Use pooled buffers, 256x256 chunk textures at 8 px/cell for far zoom
    (mip), `UPDATE_DISABLED` + release textures of chunks off-screen for > N s. Gain: phone memory/thermal headroom. Effort M.
15. **Web/wasm specifics** — export with `optimize=size` off, `-O3` templates (official release templates are fine), check that
    `gdscript/warnings` do not keep `assert`s in release; avoid `String` formatting in sim at all (wasm string ops are 3-5x slower
    than native); use typed arrays everywhere (untyped `Array` iteration boxes Variants). Gain: 10-20% across the board. Effort S.
16. **Test-suite speedups** — (a) run test files in 4 processes (`run_tests.gd --shard=i/n`, a bash driver merges results) -> ~2 min;
    (b) the 7 bot/long-run tests (~130 s) run with fewer days or share one cached bot run per seed (`tests/scenario.gd` fixture
    computed once per process, reused by determinism tests comparing hashes); (c) `Defs` already static; also cache `MapGenerator`
    output per (seed,size) inside a process. Gain: 5.5 min -> ~1.5 min. Risk: none (shards are isolated buses). Effort M.
17. **GDExtension kernel (later)** — only worth it for three kernels with stable interfaces: flow-field BFS + component labelling,
    belt step, and creature move/score loop over SoA arrays. Needs an Emscripten build of the extension for web (doable, CI step);
    determinism is preserved as long as the kernel is integer/fixed-point and reads/writes the same packed arrays. Gain: 10-30x on
    those loops. Do it only after 4 and 2 made the data layout kernel-ready; otherwise it is a rewrite twice. Effort L.

## 3. Perf contract
- Budgets (desktop headless, 250 map, 300 enemies, 8k belts, 12 colonists, 600 ticks after warm-up): threats <= 2.0 avg / 5 p95;
  logistics <= 0.5 / 1.0; colonists+jobs <= 0.5 / 1.5; contamination+mutation <= 0.5 / 2; total <= 4 / 10; first-tick spike <= 20 ms;
  flow_builds per 600 ticks <= 60 at steady state; view (xvfb) <= 40 ms/frame as a regression guard only.
- CI test `tests/test_perf_budget.gd`: runs the real `sim.step()` (not the mirror), takes the median of 3 runs x 300 ticks, fails if
  a system exceeds its budget x 1.5 (CI machines are noisy) and prints the table; `tools/perf_bench.gd` must call `step()` with
  per-system laps exposed by `Simulation` (a `profile: Dictionary` filled only when `profiling = true`).
- Determinism: every optimisation PR runs `test_golden` + `test_long_sim` + `test_qa_longrun::two_runs_same_seed`; goldens stay
  byte-identical. A change that intentionally alters results (LOD tiers, retarget heuristics) must ship a flag in `balance.json`
  defaulting to the old behaviour for existing goldens, plus regenerated goldens in the same commit with the reason in DECISIONS.md.
  Add `tools/golden_diff.gd` printing the first diverging tick and part hash to make reviews fast.

## 4. Two waves, 4-5 Sonnet workers each, disjoint files
Wave 1 (sim hot paths): W1a threat targeting cache (#1, #11) — `sim/threats/threat_model.gd`, `sim/map/spatial_hash.gd`,
`tests/test_threat_scale.gd`; accept threats <= 4 ms with 8k belts, <= 1.5 ms without, goldens identical. W1b sparse belts (#2) —
`sim/logistics/belt_grid.gd`, `tests/test_belts.gd`; accept logistics <= 0.5 ms at 8k belts, `state_hash` unchanged on `automation_chain`.
W1c flow fields (#3, #13) — `sim/map/flow_field.gd`, `sim/map/pathfinder.gd`, `sim/mutation/mutation_system.gd`; accept max tick <= 20 ms,
flow_builds <= 60/600 ticks after warm-up. W1d jobs cache (#10) + bus batching (#12) — `sim/jobs/*`, `sim/items/item_system.gd`
counters; accept identical job sequence on `tests/scenario.gd` for 3000 ticks. W1e perf contract (#16a, §3) — `tools/perf_bench.gd`,
`tests/test_perf_budget.gd`, `tests/test_runner.gd` sharding, `.github/workflows/ci.yml`; accept suite <= 2.5 min in 4 shards.
Wave 2 (view + data layout): W2a ground redraw on dirty only (#7) — `view/world_view.gd`, `view/chunk_layer.gd`; W2b MultiMesh
units + shader animation (#6) — new `view/unit_layer.gd`, `world_3d.gd` region only; W2c HUD at tick rate + int keys (#8, #9) —
`view/hud.gd`, `world_3d.gd` unit map, `building_3d.gd`; W2d Enemy SoA (#4) — `sim/threats/enemy.gd`, `threat_system.gd`,
`tests/test_threat_*`; W2e memory (#14) + wasm pass (#15). Accept: xvfb view/frame -50% vs this report, 64x64 screenshot identical,
goldens identical (W2d), static memory at 250 map < 150 MB.
Orchestrator verifies per merge: full suite green twice, `test_golden` byte-identical (`git diff --exit-code tests/golden`), the perf
table before/after in the PR report, no new `String` formatting or `duplicate()` in `sim/` hot loops (grep), and that each worker
touched only its files.

## 5. Bold ideas for the engine migration
- **Sim core as a portable library**: `sim/` already has no Node; next make all state live in packed arrays owned by one `World`
  struct (SoA for colonists, enemies, items, belts, fields) with systems as free functions. Then a Rust/C++ port is a transliteration
  and the GDExtension/wasm kernel and the GDScript fallback share one data layout (`docs/sim_contract.md` becomes the ABI).
- **Record/replay-driven profiling**: every bot game and golden is a command log; a `tools/profile_replay.gd` replays any log with
  per-system laps and emits a flame table per 100 ticks, so perf regressions come with a reproducible replay, and the CI budget test
  runs on real late-game logs instead of synthetic spawns.
- **Deterministic multithreading by chunk ownership**: partition the map into 32x32 chunks; creatures, belts and fields are updated
  per chunk in a fixed order, with cross-chunk effects queued into a next-tick mailbox sorted by (chunk, id). Single-threaded today,
  it gives the same hashes when chunks later run on worker threads (native builds; wasm stays single-threaded without COOP/COEP).
- **Tick-tiered world**: three clocks — 10 Hz near the camera/colony, 2 Hz for far creatures and idle machines, 1/day analytic
  autopilot for outposts — with state transitions defined in data and covered by goldens per tier, which is how 1000+ creatures
  and several maps fit a phone budget.
- **Fixed-point sim**: move contamination/mutation fields and distances to int32 fixed-point so a future C++/Rust kernel and any
  platform (x86 vs ARM vs wasm) produce bit-identical goldens; floats stay in the view only.
