# Sim contract (portable spec)

What a re-implementation (other engine/language) must reproduce to be "the same game": same seed + same command log
= same `state_hash` at every tick. Source of truth is the code; `tests/test_contract_doc.gd` keeps the command table and
the data-file table below in sync with it. "(GD)" marks GDScript-specific behaviour a port must emulate or replace.

## 1. Tick order (`Simulation.step()`)
`if game_over_reason != "": return`, then `tick += 1`, then in this exact order:
1. `crafting.tick` (bills)  2. `needs.tick`  3. `farming.tick`  4. `colonists.tick` (jobs, movement)
5. *research slot (pending R2a): after colonists, before logistics*  6. `logistics.tick` (belts)  7. `buildings.tick_machines`  7b. `chips.tick` (T4)
8. `perks.tick`  9. `health.tick`  10. `debt.tick`  11. `mood.tick`  12. `threats.tick`  13. `contamination.tick`
14. `mutation.tick`  15. `crises.tick`  16. `storyteller.tick`
Then: if no colonist is alive (list non-empty) `end_game("colonists_dead")`; if `tick % ticks_per_day == 0` emit `day_started`; emit `tick_advanced`.
`TICKS_PER_SECOND = 10` at 1x; `ticks_per_day = balance.ticks_per_day`. Speed (pause/1x/2x/3x) is the view's job: it only changes how many `step()` calls happen.
Commands run between steps: a command recorded at tick T was issued after step number T and before step T+1.
Construction: `Simulation.new(seed, bus, defs, opts)` then `start_new_game()` (map gen, `_init_systems()`, starting colony, `StartOpts.apply`).
System construction order in `_init_systems()` fixes id allocation and listener order.

## 2. RNG rules
- Algorithm: Godot `RandomNumberGenerator` (PCG32), `rng.seed = seed_value` in `_init`. Calls used: `randi_range(a,b)`, `randf()`, and `randf_range` in map gen.
  A port must implement the same generator or regenerate its goldens.
- Never use global `randi()/randf()`, `Time`, OS clocks or `hash()` of unordered data in sim code.
- One shared stream `sim.rng`. Its call ORDER is part of the contract: adding, removing or reordering a call shifts every later roll. Users:
  map generation (once, at start), colonist generation (`Generator`, `Skills` init), `quality` (2 `randf` per roll), `combat` hit roll
  (short-circuit: `aimed or randf() < hit_chance`), `health` (part pick, `randf() < chance`), `building_system` (craft_save roll, cave-in damage),
  `mood` (break chance, machine pick), `break_job` (2 `randi_range` for target offset), `storyteller` events and crisis picks (chance roll first, then picks),
  `colonist_system` name pick. `StartOpts.apply` reseeds `rng.seed = seed*31 + site*104729` when `opts.site` is set.
- Independent streams that never touch `sim.rng`: `debt` seed `seed*7919+13`; `idle_work` `seed ^ 0x1D1E`; `mutation` `seed ^ 0x3A7B`; storyteller chain stream `_prng` `seed ^ 0x9E3779`.
- Pick-from-list rolls index lists in deterministic order (id order or insertion order), never an unordered Dictionary walk.

## 3. Determinism and number rules
- State is ints, bools, strings, floats, cells (`Vector2i`), arrays, and Dictionaries with string/int keys. No Callables, Nodes or signals in state.
  Cell-keyed Dictionaries are lookup-only in tick paths.
- Iterate each system's `list` (insertion order = id order). To walk a Dictionary, walk a sorted key list.
- Ints: ticks, ids, counts, stack sizes. Ids are allocated monotonically per system and never reused.
- Floats: 64-bit IEEE double (hp, needs, contamination, mood, xp). Keep operation order (no FMA, no reassociation).
  `int()` truncates toward zero; int `/` int is integer division in GDScript (`day() = tick / ticks_per_day`); `roundi` rounds half away from zero.
- JSON numbers read back as floats; every consumer wraps with `int(...)` (saves too, see 7).
- No gameplay number is hard-coded in systems; all live in `data/*.json`.

## 4. Commands (recorded in `command_log` as `[tick, name, args]`)
Each command calls `_record(name, args)` as its FIRST line, even if validation later fails (a rejected command replays as rejected). `_record` is a no-op while `replaying`.
Arg types: int, bool, string, cell (`Vector2i`), `[cell]`. Return value is not saved. A failed command changes no state.
Unrecorded helpers (tests/tools only): `place_instant`, `set_patrol_route` (wraps `set_patrol_route_text`).

| command | args | returns | validation / effect |
|---|---|---|---|
| `designate_mine` | c: cell, on: bool | void | ignored if out of bounds; sets mine designation |
| `set_zone` | c: cell, zone_id: str | bool | `""` clears; else cell passable, unoccupied, zone in `zones.json` |
| `place_building` | def_id: str, c: cell | Blueprint or null | def exists and `buildable`; `placement_error(def,c,false)` empty (research gate pending R2a) |
| `deconstruct` | c: cell | bool | building at c removed, partial refund |
| `set_rule` | rule_id: str, on: bool | void | rule in `rules.json`; emits `rule_changed` only on change |
| `set_alarm` | on: bool | void | emits `alarm_changed` only on change |
| `place_belt` | cells: [cell], last_dir: int | bool | atomic: non-empty, dir 0..3 (N,E,S,W), no repeats, each cell free (passable, no building or blueprint), consecutive cells 4-adjacent |
| `remove_belt` | cells: [cell] | bool | true if any belt removed |
| `set_belt_dir` | c: cell, dir: int | bool | dir 0..3 and belt at c |
| `add_bill` | building_id: int, recipe_id: str, mode: str, target: int | int (bill id or -1) | building takes bills, recipe valid for station, mode in `crafting.modes` |
| `remove_bill` | building_id: int, bill_id: int | bool | bill exists |
| `update_bill` | building_id: int, bill_id: int, mode: str, target: int, paused: bool | bool | bill exists, valid mode |
| `set_zone_filter` | c: cell, item_id: str, allowed: bool | bool | applies to the whole connected zone group |
| `set_zone_priority` | c: cell, priority: int | bool | 0 low, 1 normal, 2 high (`crafting.priorities`) |
| `set_work_priority` | colonist_id: int, work_type: str, p: int | bool | colonist exists, type in `work.json`, 0 <= p <= `max_priority` |
| `set_research` | tech_id: str | bool | tech exists, prereqs done, tier unlocked, affordable; moves it to the queue front, spends essence on first queue |
| `queue_research` | tech_id: str, on: bool | bool | on: as set_research but appended; off: removes, exact essence refund if progress is 0 |
| `install_chip` | building_id: int | bool | T4: building has `chip_slots` > 0 (bench/smelter/assembler, never a miner), no chip yet, not broken, tech `ai_chips` done (when gating), one `ai_chip` in storage (ledger sink `chip_install`) |
| `remove_chip` | building_id: int | bool | T4: chip drops on the building cell (ledger source `chip_remove`) |
| `deliver_audit` | tier: int | bool | warden_terminal exists; consumes only still-required parts of that tier's set from storage; completes -> research.unlock_tier(tier) + warden letter once |
| `set_drafted` | colonist_id: int, on: bool | bool | colonist exists and alive |
| `order_move` | colonist_id: int, cell: cell | bool | colonist drafted, cell reachable |
| `order_attack` | colonist_id: int, enemy_id: int | bool | drafted colonist, enemy alive |
| `resolve_crisis` | crisis_id: str, option_id: str | bool | crisis active, option exists |
| `answer_event` | event_uid: int, accept: bool | bool | pending storyteller choice with that uid |
| `set_turret_ammo_policy` | building_id: int, policy: str | bool | turret exists, policy in `ammo.json` policies |
| `learn_perk` | colonist_id: int, perk_id: str | bool | colonist exists, perk point and prereqs, not yet learned |
| `use_perk` | colonist_id: int, perk_id: str | bool | learned, off cooldown |
| `respec_perks` | colonist_id: int | bool | pays `perks.respec_cost` |
| `accept_contract` | contract_id: int | bool | offer open |
| `decline_contract` | contract_id: int | bool | offer open |
| `deliver_contract` | contract_id: int | bool | accepted and goods in storage |
| `pay_debt` | colonist_id: int, amount: int | bool | essence in storage, debt open (ledger sink "debt") |
| `set_quota` | colonist_id: int, per_day: int | bool | colonist has debt; 0 = off |
| `choose_payoff` | colonist_id: int, stay: bool | bool | debt fully paid, choice pending |
| `set_patrol_route_text` | text: str ("x,y;x,y") | void | empty = automatic ring around the base |
| `purify_cell` | c: cell | bool | spends refined essence, cleans the field around c |

### Research (pending R2a)
Research commands (queue/cancel research, audit delivery) are being added by R2a. Placeholder: R2a/orchestrator must add each new `_record`
command as a table row in the table above (the test fails until they are listed), and describe the research tick slot, the bench-operator work rule
(completion after exactly `bench_ticks` of operator work), and the ledger spend/refund of essence here.

## 5. Event bus
`autoload/event_bus.gd` declares every cross-system signal (about 70: tick/day, tile/zone/designation changes, building and blueprint lifecycle,
waves and raids, colonist/health/mood/skill events, contracts, debt, perks, crises, run end, mutation). Signals are an observer channel plus some
inter-system wiring through `Simulation.listen`. Reactions must be deterministic and synchronous in emission order. A port may use direct calls or
event queues but must preserve listener order (registration order in `_init_systems`).

## 6. Data files (`data/*.json`, loaded by `Defs`, read-only after load)
`events_prison.json` is merged into `events`. Keys starting `_comment`/`_doc` are ignored. A port loads the files verbatim.
| file | top-level schema |
|---|---|
| `ammo.json` | item, turret{}, pouch{}, policies[], default_policy |
| `arrivals.json` | max_colonists, choice_timeout_ticks, age_min/max, max_traits, trait_chance, stories |
| `balance.json` | ticks_per_day, automation, map{width,height,clusters}, colony{colonists,engineers,start_items,start_stockpile_size}, colonist, mining, construction, waves... |
| `biomes.json` | biome id -> {resources, purity_weights, node_density, hazard} |
| `buildings.json` | id -> {name, size[2], color, max_hp, cost{item:n}, buildable, shelter, critical, ...} |
| `contracts.json` | first_offer_day, offer_interval_days, offer_ttl_days, max_open, anger, templates[] |
| `crafting.json` | modes[], priorities[], default_priority, default_bill_target |
| `crises.json` | settings{}, crises id -> {options...} |
| `debt.json` | item, debt_min/max, due_days, despair_*, riot/escape tuning |
| `enemies.json` | id -> {name, max_hp, move_ticks, damage, attack_cooldown_ticks, attack_range, threat_cost} |
| `event_chains.json` | random_enabled, chance, steps[], complication, inspection_quota_default |
| `events.json` | id -> {weight, min_day, harmful, max_per_game, requires, text, ...} |
| `events_prison.json` | same schema as events.json, prison-themed |
| `health.json` | parts, kinds, pain_scale/weight, downed_consciousness, shelter_collapse |
| `idle_work.json` | cleanup{}, patrol{}, training{} |
| `items.json` | id -> {name, color, stack, value} |
| `jobs.json` | flee/repair/operate/haul/mine tuning |
| `meta.json` | legacy, next_batch, scout_cells, unlocks (cross-run meta, enters the sim via `opts`) |
| `milestones.json` | tiers id -> {parts{item:n}} audit deliveries per tier |
| `models.json` | art model descriptors (view only, not read by sim) |
| `mood.json` | base, check_ticks, thresholds, chances, thoughts |
| `mutation.json` | update_ticks, cap, diffusion, decay, bloom/illness chances |
| `threat.json` | enabled (threat_v2), d0, k_poll, stick, pull_ratio, region_size/cap_per_region, recompute_ticks, base/state_mod/colonist_mod/species_bias; def fields `threat`, `threat_mods`; API `ThreatSystem.pick_target(e)`, `Building.threat_now(sim)`, `Building.threat_flags` |
| `names.json` | names[], backstories[] |
| `needs.json` | start_food/rest, retry_ticks, food{}, rest{} |
| `perks.json` | caps, respec_cost, perks id -> {skill, level, effect}, levels_per_point |
| `plants.json` | id -> {item, yield, grow_ticks, sow_ticks, harvest_ticks, min_daylight} |
| `quality.json` | tracked, skill, levels, thresholds, base, per_level, noise |
| `raids.json` | id -> {min_points, weight, spawn, retreat_fraction, units[]} |
| `recipes.json` | id -> {name, inputs{}, outputs{}, work_ticks, station} |
| `research.json` | techs id -> {name, tier, prereqs[], cost{essence}, bench_ticks, unlocks{buildings,recipes,rules}, waste_mult} |
| `chips.json` | T4: item, tech, recipe, chip_speed 0.8, chip_threat_mult 2.0, chip_waste_mult 1.3, upkeep_item/upkeep_per_day, calibration_days 3, calibrate_ticks, calibrate_min_skill (operating) |
| `resources.json` | id -> {item, tier, biomes, base_rate, purity_mult} (infinite nodes) |
| `rules.json` | id -> {name, default: bool, ...} player rules (`set_rule`) |
| `skills.json` | max_level, xp_base, xp_step, xp_per_work_tick, speed_per_level, passion_xp |
| `time.json` | start_hour, dawn/dusk hours, night_daylight |
| `traits.json` | traits id -> {effects} |
| `weapons.json` | combat{}, weapons id -> {damage, range, cooldown, ...} |
| `work.json` | default_priority, max_priority, types{} |
| `xp.json` | day_survived, wave_repelled, colonist_rescued, first_refine, event_choice |
| `zones.json` | id -> {name, color, accepts[], waste_emission_factor} |


## 7. Save format v2 (`SaveGame`)
Saves are command-log replays, not state snapshots:
`{"version": 2, "seed": int, "defs_hash": int, "tick": int, "commands": [[tick, name, args], ...], "opts": {...}}`.
- Arg encoding: cell -> `{"v":[x,y]}`; cell array -> `{"a":[[x,y],...]}`; other scalars as-is.
- Load checks: missing key -> `corrupt`; `version != 2` -> `version` (v1 incompatible); `defs_hash` differs -> `defs_changed`.
- Replay: new sim with `seed`/`opts`, `start_new_game()`, `replaying = true`; loop: apply every command with `cmd.tick <= sim.tick` in log order;
  stop when `sim.tick >= tick` or game over; else `step()`. Float args become ints; `opts` keys `scout`, `site`, `crate{}` are int-normalised. Then `replaying = false`.
- `defs_hash`: hash of sorted-key JSON of every Dictionary property of `Defs` (GD `String.hash()`). Only equality with the same engine's defs matters; cross-engine saves are unsupported.
- `opts`: `scout`, `site`, `crate` (item->count), `map_w`, `map_h`, meta unlock flags; consumed by `StartOpts.apply` and part of the replay input.

## 8. `state_hash` (`SaveGame.state_hash(sim)`)
An `int` hash of observable state. Parts in order: `[tick, game_over_reason, alarm]`; each `items.stacks` entry `[cell, stack]` (insertion order);
each colonist in `colonists.list` `[id, cell, hp, alive, carry_item, carry_count, carry_quality, learned_perks]`; each building in `buildings.list`
`[id, def_id, cell, hp, condition, broken, input, output, output_q]` and again `[..., output, ammo, ammo_policy]`; `hash(mutation.field)`;
`logistics.state_parts()` = `[belt_count, belts.state_hash()]`.
(GD) Today it is `var_to_str(parts).hash()` (Godot text serialisation, 32-bit string hash): engine-specific, a port cannot match it bit for bit.
Portable definition for cross-engine comparison: canonical JSON of the same parts (UTF-8, no whitespace, object keys sorted, ints as ints, floats as shortest
round-trip decimal, cells as `[x,y]`) fed to a stable hash such as FNV-1a 64. Switching changes every golden (`tests/golden/`, R1b), so it is deferred.
Not covered by the hash today (known gaps): needs, mood, skills/xp, injuries, contamination levels, bills, contracts, debt, enemies, rng state.

## 9. Architecture constraints a port must keep
`sim/` has no rendering, Node, scene tree or autoload lookups; the view only reads state, listens to the bus and issues commands through `Simulation` methods.
Systems are modules (`core, map, colonists, jobs, items, buildings, contamination, threats, storyteller, ...`); systems read map/items, never the view.
Reachability: grid A* plus connected components (O(1) reachable test); equal-cost tie-break by neighbour order N,E,S,W.
Job reservations use string keys; flee overrides all jobs while the alarm is on.

## 10. AI chip operator (T4, `sim.chips`)
A chip replaces the operator of a bench/smelter/assembler: bench adds `bench_rate * chip_speed` per tick without a colonist; a processor takes 4 of 5 work steps (accumulator, no rng).
Waste of a chip building is scaled by `chip_waste_mult` (fraction rolled on `sim.rng`, only with a chip, so chipless games are unchanged). Upkeep: `upkeep_per_day` refined essence
at each day start (retried every tick while unpaid; unpaid = chip stops). Calibration is due `calibration_days` after install/last calibration; then the chip stops until a colonist
with `operating` >= `calibrate_min_skill` runs `CalibrateJob` (`calibrate_ticks` ticks on site). A broken or destroyed building drops its chip.
Read-only API for the threat system: `chips.threat_mult(building)` (`chip_threat_mult` while the chip is busy, else 1.0) and `chips.colony_threat_mult()` (max over busy chips).
`ai_chip` is accepted by the stockpile zone; recipe `make_ai_chip` (assembler) needs tech `ai_chips`. Chip state is not in `state_hash`; it is rebuilt by command replay.
