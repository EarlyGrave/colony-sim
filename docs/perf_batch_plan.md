# Perf batch P1 "250x250 map, 300 creatures" — plan (from prompter)
One wave, 5 parallel Sonnet workers (P1..P5). Targets (phone web, single-threaded wasm): sim <= 10 ms/tick at 3x
(desktop-headless budget <= 3 ms/tick so wasm ~3x slower still fits), view <= 16 ms/frame. GDExtension/C++ out of scope.
## Common rules
- Start with `git reset --hard claude/colony-sim-godot-4jftsm`. Commit in your worktree, NEVER push.
- Determinism: same seed + commands = same game. Existing tests are the spec; no `randi()/randf()/Time` in sim,
  no iteration over Dictionary/unordered sources where order changes results (sort keys or use arrays/ids).
  Optimisations must not change results at default 64x64 unless a test is updated with justification in the report.
- No gameplay numbers hard-coded: new tunables go to `data/balance.json` (own sub-key per agent). Default map stays 64.
- Shared files only inside `# region <agent>` blocks; hooks in existing functions are one line.
- After adding a `class_name`: `godot --headless --path . --import`; then ALL tests green:
  `godot --headless --path . res://tests/run_tests.tscn` (~3 min, run in background, poll).
- P2..P5 may use their own quick `Time.get_ticks_usec()` timing (view/tool code only, not sim) until P1 is merged;
  final numbers should use `tools/perf_bench.gd` if present.
- Report <= 30 lines in `docs/agents/<agent>/P1-report.md`: done / not done / files / tests / before-after numbers.
## P1 benchmark + map-size option (do first-class, small)
- Owns: `tools/perf_bench.gd` + `tools/perf_bench.tscn`, `sim/core/start_opts.gd`-equivalent (find `StartOpts`) region P1,
  `sim/map/map_generator.gd` size plumbing, `data/balance.json` map key only, `tests/test_perf_bench.gd`.
- Goal: start opt `map_w`/`map_h` (default from balance, 64) honoured by MapGrid/generator/Pathfinder/camera bounds
  (grep hard-coded 64). Bench args: `-- --size=250 --enemies=300 --ticks=600 --seed=1 --view=0|1`.
- Spawn enemies only via existing sim APIs (threat system spawn / opts), placed deterministically via `sim.rng`.
- Prints per-system ms/tick avg and p95 (colonists, jobs, threats, contamination, mutation, storyteller, buildings,
  combat) by timing each step part; with `--view=1` (xvfb) prints view ms/frame avg/p95 (process + draw).
- Accept: 250x250 map generates and runs 600 ticks without errors; default 64 tests unchanged; baseline table
  (64/300 creatures and 250/300) committed in report. Tests: size opt yields map of requested size and a still
  connected colony area; bench `--ticks=20 --size=96 --enemies=20` exits 0 and prints all system lines.
## P2 contamination + mutation fields
- Owns: `sim/contamination/*`, `sim/mutation/mutation_system.gd`, `view/` contamination overlay code in
  `world_view.gd` (`# region P2` around `_draw_contamination_field`), `tests/test_field_perf.gd`.
- Goal: time-sliced diffuse/normalize/detect (process 1/N of cells per tick in fixed order, or a coarse grid, N and
  cell size in balance.json) and a dirty-rect/dirty-flag scheme; overlay as one `ImageTexture` updated via
  `Image.set_pixel` only for changed cells (no per-cell `draw_rect`), upscaled with nearest/linear.
- Accept: 250x250 contamination+mutation <= 1.5 ms/tick avg, p95 <= 4 ms; overlay <= 1 draw call and <= 1 ms/frame;
  existing contamination/mutation tests pass; same seed twice gives identical field hash after 500 ticks.
- Tests: field hash determinism; sliced result converges to within tolerance of full update after K ticks;
  overlay image size equals map size and pixel colour matches field value for 3 sample cells.
## P3 creatures at scale
- Owns: `sim/threats/*`, `sim/map/pathfinder.gd` (new `flow_field.gd`, `spatial_hash.gd` in `sim/map/`),
  `tests/test_threat_scale.gd`.
- Goal: shared flow fields (Dijkstra/BFS from a target cell, cached per target, invalidated by map/wall version
  counter) for creature movement; target re-evaluation every N ticks staggered by `enemy.id % N` (N in balance.json);
  spatial hash (cell bucket) for range queries by turrets/colonists/enemies; no per-enemy A* in steady state.
- Accept: 300 enemies on 250x250 <= 3 ms/tick avg, p95 <= 8 ms (threat+combat); no A* calls per tick after
  warm-up (counter exposed); all combat/threat tests pass; waves still reach the colony (balance_report outcomes
  within the same win/lose class for the usual seeds).
- Tests: flow field step reduces distance to goal every move; stagger means each enemy re-targets once per N ticks;
  spatial hash query equals brute-force query on random data (sim.rng); cache invalidation after wall placed.
## P4 view at scale
- Owns: `view/world_view.gd` (ground/terrain drawing outside region P2), `view/world_3d.gd`, new
  `view/chunk_layer.gd`, `view/camera_controller.gd` only for visible-rect helper, `tests/test_view_chunks.gd`.
- Goal: ground in 32x32-cell chunks (one ImageTexture/SubViewport per chunk, redraw only dirty chunks on tile
  change signal); `_rebuild_blocks` becomes per-chunk MultiMesh (rebuild only chunks of changed tiles); frustum /
  visible-cell-rect culling of unit, enemy, item and effect sprites (hide nodes outside view + margin); pooled sprites.
- Accept: 250x250 view with 300 enemies <= 16 ms/frame avg under xvfb (report number, state GPU is software);
  single tile change touches <= 1 chunk (counter); memory: no single 250*16 px texture; screenshot at default zoom
  identical to before except noise (attach path); 64x64 look unchanged.
- Tests: world->chunk mapping and dirty set for edit at chunk border (marks both chunks); culling predicate
  includes on-screen, excludes far cell; block chunks cover all solid tiles exactly once.
## P5 (optional, only if P1-P4 scope is done) jobs scan caching
- Owns: `sim/jobs/job_system.gd`, `sim/jobs/givers/*`, `tests/test_job_cache.gd`.
- Goal: work-giver scans iterate cached candidate lists (mine designations, haul items, build sites) rebuilt on
  version counters / bus events instead of scanning the whole map per colonist; stagger idle colonists' searches.
- Accept: jobs <= 1 ms/tick avg at 250x250 with 20 colonists; identical job assignment order on a fixed scenario
  (record job sequence for 500 ticks before/after; must match or justify).
- Tests: cache invalidated on designation add/remove; assignment sequence equals brute-force scan reference.
## Merge order
P1, P3, P2, P4, P5. Conflicts only in `# region` blocks / balance.json. Then full tests, perf_bench 250/300 table in
PROGRESS.md, one screenshot.
