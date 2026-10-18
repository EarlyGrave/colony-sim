# Automation batch A1/A2 "nodes, machines, belts" — plan (from prompter) — STATUS: QUEUED (after perf batch P1)
Two waves, 4-5 parallel Sonnet workers each. Plans only; no code written yet. Factorio/Satisfactory-lite, touch-first.
## Goals
- Ore deposits (consumed) become infinite resource NODES with purity (impure 0.5x / normal 1.0x / pure 2.0x speed).
- Hand phase -> automation: colonists mine nodes and refine by hand (workbench/refinery); then miner -> belt -> smelter -> belt -> storage.
- Dilemma kept: every refine batch (hand or machine) adds waste/contamination; automation multiplies throughput, so it multiplies pollution.
- Start map: only `essence_ore` + basic ore(s). Advanced resources live in other maps defined in data (travel NOT built now).
- Architecture: sim/ pure RefCounted, deterministic (`sim.rng`, fixed tick, arrays/ids not Dictionary order), JSON data, commands via
  `Simulation` methods that call the command-log helper (see `command_log`, `sim/core/save_game.gd`), view reads only.
## Common rules (all workers)
- `git reset --hard claude/colony-sim-godot-4jftsm`; commit in worktree, never push; shared files only in `# region <agent>`; one-line hooks.
- New tunables in `data/balance.json` (sub-key `automation`); new `class_name` -> `godot --headless --path . --import`; ALL tests green
  (`godot --headless --path . res://tests/run_tests.tscn`, ~3 min, background). Report <= 30 lines: `docs/agents/<agent>/<batch>-report.md`.
## Data model (new/changed)
- `data/resources.json`: id -> {item, tier, biomes[], base_rate (items per 100 ticks), purity_mult {impure,normal,pure}}.
- `data/biomes.json` (map defs): id -> {resources + weights, node_density, purity_weights, rock/ground mix, hazard}; `start_biome` in balance.
  Future expedition = new Simulation/MapGrid from another biome id; `MapGrid.biome_id` stored now, travel left out.
- `data/items.json`: add `copper_ore`, `iron_ore`, `ingot_*`, `plate`, `parts` etc. (few, basic tier only); `data/recipes.json`: add `station`
  field list (`smelter`, `assembler`) next to existing `benches`; recipe `waste` outputs mandatory for refining stations.
- `data/buildings.json`: `miner` (on node, 2x2), `smelter` (=refiner machine), `assembler`, `storage_in`/`storage_out` (port + buffer),
  `belt`, `splitter`, `merger` (wave 2, optional); each with `ports: [{dx,dy,dir,kind:in|out}]`, `power` (see Q1).
- `MapGrid`: `node_res: PackedByteArray` (0 none), `node_purity: PackedByteArray`, `levels` reserved: every Node/Building/Belt gets
  `level: int = 0` (always 0 now; keyed `(x,y,level)` helpers only in new code), `biome_id: String`. Tile.DEPOSIT kept as legacy tile
  (cave-in/`collapse_deposit` in `sim/storyteller/storyteller.gd` retargeted to nodes -> "node blocked by rubble" timed, never deleted).
- `sim/logistics/` (new dir): `belt_grid.gd` (dense arrays: dir, item id, progress per cell), `logistics_system.gd`, `port.gd`.
  Tick order: colonists -> logistics -> threats -> contamination -> storyteller. Belt speed = balance cells/sec; one item per belt cell
  slot, advance in fixed cell-index order (sorted), blocked = stall, no random. Colonist load/unload via existing haul giver rules.
- Commands (all recorded): `place_belt(path: Array[Vector2i])` (drag path), `set_belt_dir`, `place_building` (reuse), `set_machine_recipe`,
  `remove_belt(cells)`. Replay in `save_game.gd` unchanged (log of name+args).
## Wave A1 (foundation, 5 workers)
- A1a nodes: owns `sim/map/map_grid.gd` (region A1a), `map_generator.gd` (region), `data/resources.json`, `data/biomes.json`, `sim/jobs/mine_job.gd`,
  `sim/jobs/givers/mine_giver.gd`, `tests/test_nodes.gd`. Accept: seed 1..5 on 64x64 each has >= 8 nodes, >= 3 within 20 cells of HQ, purity mix
  within 15% of weights; mining a node 1000 times never depletes it; yield per cycle ratio impure:normal:pure = 1:2:4 vs rate (exact numbers from
  json); same seed twice = identical node arrays.
- A1b items/data: owns `data/items.json`, `data/recipes.json`, `data/buildings.json` entries, `sim/core/defs.gd` (region A1b: validate ports/biomes),
  `tests/test_automation_defs.gd`. Accept: Defs loads; every recipe item/station exists; every machine has >= 1 in and
  >= 1 out port; refining recipes have waste > 0.
- A1c belts core: owns `sim/logistics/*`, `tests/test_belts.gd`. Accept: item moves N cells in exactly N*ticks_per_cell ticks; line of 20 belts
  conserves items (in = out + on-belt) over 1000 ticks; blocked end stalls without loss; loop of belts deterministic hash equal over 2 runs.
- A1d commands + save: owns `sim/core/simulation.gd` (region A1d: `place_belt`, `remove_belt`, `set_belt_dir`), `sim/core/save_game.gd` (region),
  `tests/test_belt_commands.gd`. Accept: save/load round trip gives equal `state_hash` with 50 belts; drag path of 30 cells = 1 recorded command;
  invalid cells (rock, building) reject the whole path atomically.
- A1e hand-phase balance + migration: owns `sim/buildings/*` hooks (region A1e), `tests/scenario.gd` (region), updates of `tests/test_map.gd`
  (`test_depleting_deposit_opens_tile`), storyteller cave-in tests. Accept: see Migration; manual economy: colonist-only run 5 days yields
  >= old ore income -10%/+30% on seeds 1..5 (`tools/balance_report.gd` table in report).
## Wave A2 (machines + view + UI, 4-5 workers; after A1 merged)
- A2a miner/smelter/assembler: owns `sim/buildings/machine.gd`, `building_system.gd` (region A2a), `tests/test_machines.gd`. Accept: miner on
  normal node outputs rate*1.0 items/100 ticks to its out port +-1; smelter consumes recipe inputs from in port, emits outputs + waste; waste is
  dropped to contamination exactly as hand refinery (per-batch value equal); no input -> idle, no loss; wear/broken works as refinery.
- A2b ports + storage: owns `sim/logistics/port_link.gd`, storage_in/out in `item_system.gd` (region A2b), `tests/test_ports.gd`. Accept: machine out
  port facing a belt inserts; belt facing in port feeds; storage_out buffer 200 items; colonist hauls to/from port buffers via haul giver.
- A2c view 3D: owns `view/belt_layer.gd` (new MultiMesh per 32x32 chunk), `view/building_3d.gd` (region A2c: machine models, port arrows),
  `view/world_3d.gd` (region A2c), `tests/test_belt_view.gd`. Accept: 2000 belt cells <= 1 draw call per chunk; items on belts as MultiMesh
  instances; 250x250 view stays within perf batch frame budget.
- A2d touch UI: owns `view/panels/automation_panel.gd`, `view/hud.gd` (region A2d), `view/game.gd` (region A2d), `tests/test_belt_input.gd`.
  Accept: one-finger drag paints a belt path (Manhattan snapped, direction from drag), buttons >= 64 px, undo last path, pinch/pan untouched,
  ignore `DEVICE_ID_EMULATION` mouse; preview shows red on invalid cells.
- A2e contamination + balance + QA: owns `sim/contamination/*` (region A2e), `data/balance.json` automation keys, `tests/qa_bot.gd` region,
  `tests/test_automation_flow.gd`. Accept: end-to-end miner->belt->smelter->belt->storage produces >= X refined/day (X in report) and
  contamination/day with 3 smelters >= 2.5x with 1; bot 25 days x 5 seeds ends no worse than baseline class; forecast model includes machines.
## Migration of saves/tests
- Saves are command logs (replay on fresh sim) + defs hash: old saves replay on the new generator and will diverge; bump save version and show
  "old save incompatible" (Q8). Tests relying on consumption: `test_map.gd::test_depleting_deposit_opens_tile`, `take_from_deposit`, storyteller
  collapse tests, `scenario.designate_nearest_deposits`, balance_report. Keep `MapGrid.take_from_deposit` as compat shim for one wave (nodes
  return full amount, never deplete) and update tests to assert infinity; add `deposit_amount` shim removal in A2.
## Risks
- Belt perf at 250x250 (dense arrays, process only non-empty cells, dirty lists); view draw calls (chunk MultiMesh); deadlocks/loops (stall is legal);
  balance explosion (automation too strong -> contamination scales; cap machines per power/waste); touch drag precision; scope creep (no fluids, no floors).
## Open questions for the owner (Russian)
1. Нужна ли энергия машинам? Предлагаю БЕЗ энергии на старте (проще; ограничение — износ и отходы); генератор добавить позже.
2. Чистота ноды: множители 0.5x / 1x / 2x по скорости — ок? Или менять ещё долю отходов?
3. Какие базовые руды кроме эссенции (медь, железо?) и сколько нужно до пачки «другие карты»?
4. Падает ли на ноды заражение/существа (нода «засоряется» временно) или нода неприкосновенна?
5. Конвейер: одна лента 1 предмет на клетку, скорость ~2 клетки/с — достаточно, или нужны уровни ленты?
6. Разделители/слияния — в первую волну или во вторую (я предлагаю A2 опционально)?
7. Колонисты должны уметь возить в/из машин вручную всегда (да по умолчанию) — ограничить ли?
8. Старые сохранения: просто пометить несовместимыми (рекомендую) или писать миграцию?

## Owner answers (2026-10-18) — binding for workers
1. No power for machines at start (generator later). 2. Purity 0.5x/1x/2x affects speed only.
3. Base ores on the start map: copper_ore + iron_ore (+ essence_ore). 4. Nodes are invulnerable
(no clogging by contamination/creatures). 5. One belt tier, 1 item per cell, ~2 cells/s.
6. Splitters/mergers: later, NOT in A1/A2. 7. Manual hauling into/out of machines always available.
8. Old saves: bump save version, mark incompatible (no migration).
