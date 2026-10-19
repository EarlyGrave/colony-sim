# Sim contract (portable spec)
What a re-implementation (other engine/language) must reproduce to be "the same game": same seed + same command log
= same `state_hash` at every tick. Source of truth is the code; `tests/test_contract_doc.gd` keeps the command table and
the data-file table below in sync with it. "(GD)" marks GDScript-specific behaviour a port must emulate or replace.
## 1. Tick order (`Simulation.step()`)
`if game_over_reason != "": return`, then `tick += 1`, then in this exact order:
1. `crafting.tick` (bills)  2. `needs.tick`  3. `farming.tick`  4. `colonists.tick` (jobs, movement)
5. *research slot (pending R2a): after colonists, before logistics*  6. `logistics.tick` (belts)  7. `power.tick` (L3: networks, fuel burn, brownout) then `buildings.tick_machines`  7b. `chips.tick` (T4)
8. `perks.tick`  9. `health.tick`  10. `debt.tick`  11. `mood.tick`  12. `threats.tick`  13. `contamination.tick`
14. `mutation.tick`  14b. `ecology.tick` (T5: nest hunger banks, rally letter)  15. `crises.tick`  16. `storyteller.tick`
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
- Independent streams that never touch `sim.rng`: `debt` seed `seed*7919+13`; `idle_work` `seed ^ 0x1D1E`; `mutation` `seed ^ 0x3A7B`; `ecology` `seed ^ 0xEC01` (nest placement at `start_new_game`, mutant-variant rolls); storyteller chain stream `_prng` `seed ^ 0x9E3779`.
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
| `set_rule` | rule_id: str, on: bool \| mode: str | void | rule in `rules.json`; emits `rule_changed` only on change. Rules with `modes` (`turret_target_mode`: nearest/threatening/weakest, `repair_priority`: nearest/belts/machines/turrets) take a mode string, invalid ignored; read via `get_rule_mode(id)` |
| `set_alarm` | on: bool | void | emits `alarm_changed` only on change |
| `place_belt` | cells: [cell], last_dir: int | bool | atomic: non-empty, dir 0..3 (N,E,S,W), no repeats, each cell free (passable, no building or blueprint), consecutive cells 4-adjacent |
| `remove_belt` | cells: [cell] | bool | true if any belt removed |
| `set_belt_dir` | c: cell, dir: int | bool | dir 0..3 and belt at c |
| `place_belt_node` | kind: int, c: cell, dir: int | bool | L2: kind 1..4 (splitter_basic/smart/priority, merger), dir 0..3, building def of that kind researched, cell free or plain belt (replaced) |
| `set_splitter_filter` | c: cell, slot: int, value: str | bool | L2: smart node at c, slot 0..2 (left/front/right), value `any`/`overflow`/item id |
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
| `deliver_petition` | phase: int (1..4) | bool | e1_enabled + audit tier 2 + warden_terminal; phases sequential; consumes only still-required items; completing pays the reward (debt cut %, items, tier 3 on P3) and emits petition_phase_done |
| `deliver_shuttle_parts` | none | int | s1_enabled + petition P4 done + a Release Gantry; consumes part_cost per part from storage up to the need; returns parts added (S1) |
| `launch_shuttle` | none | bool | phase ready (all parts, gantry powered); starts the countdown and siege waves (S1) |
| `repair_gantry` | none | bool | pays repair_cost, restores gantry HP (S1) |
| `deliver_audit` | tier: int | bool | warden_terminal exists; consumes only still-required parts of that tier's set from storage; completes -> research.unlock_tier(tier) + warden letter once |
| `trigger_bell` | building_id: int | bool | Mourning Bell exists, not broken, no burst running, cooldown 0; starts burst (threat x`burst_mult` for `burst_ticks`, then `cooldown_ticks`); debits `essence_cost` refined essence from storage, shortfall -> ledger event `decoy_essence_debt` |
| `set_drafted` | colonist_id: int, on: bool | bool | colonist exists and alive |
| `order_move` | colonist_id: int, cell: cell | bool | colonist drafted, cell reachable |
| `order_attack` | colonist_id: int, enemy_id: int | bool | drafted colonist, enemy alive |
| `form_squad` | ids: str (JSON int array), roles: str (JSON array, "" / "auto" / [] = by affinity) | int | C1: squad id or -1; 1..`roles.max_size` (4) living, unsquadded, unique members; members drafted, role weapon equipped |
| `disband_squad` | sid: int | bool | C1: squad exists; members un-drafted, weapons restored |
| `squad_hold` | sid: int, cell: cell | bool | C1: cell passable; members `order_move` to cell + role offset (nearest free reachable cell); clears focus |
| `squad_focus` | sid: int, enemy_id: int | bool | C1: enemy alive; non-medic members `order_attack` |
| `resolve_crisis` | crisis_id: str, option_id: str | bool | crisis active, option exists |
| `answer_event` | event_uid: int, accept: bool | bool | pending storyteller choice with that uid |
| `answer_quest` | uid: int, option_id: String | bool | pending quest choice; false if disabled/unknown |
| `set_turret_ammo_policy` | building_id: int, policy: str | bool | turret exists, policy in `ammo.json` policies |
| `learn_perk` | colonist_id: int, perk_id: str | bool | colonist exists, perk point and prereqs, not yet learned |
| `use_perk` | colonist_id: int, perk_id: str | bool | learned, off cooldown |
| `respec_perks` | colonist_id: int | bool | pays `perks.respec_cost` |
| `use_ability` | squad_id: int, ability_id: str | bool | C2: squad has a living member in the ability role, off cooldown, `essence_cost` refined_essence in storage (stabilise: a Down inmate in range and `health.stabilise`); pays essence, puffs contamination at the user, sets threat flag `burst` |
| `accept_contract` | contract_id: int | bool | offer open |
| `decline_contract` | contract_id: int | bool | offer open |
| `deliver_contract` | contract_id: int | bool | accepted and goods in storage |
| `dispatch_sector` | tier: int, modifier_id: String | bool | E2 (e2_enabled): bundle in storage, tier in order; grants one permanent modifier |
| `pay_debt` | colonist_id: int, amount: int | bool | essence in storage, debt open (ledger sink "debt") |
| `set_quota` | colonist_id: int, per_day: int | bool | colonist has debt; 0 = off |
| `choose_payoff` | colonist_id: int, stay: bool | bool | debt fully paid, choice pending |
| `dispatch_party` | ids: [int], supplies: {item: n} (logged as JSON text) | Dictionary {ok, crew[], supplies{}} | R4b: all ids alive and distinct, supplies in storage; atomic (failure = no change). Removes colonists, consumes supplies (ledger sink `expedition`); crew snapshots {name, engineer, skills, passions}. Empty ids + non-empty supplies = sling crate (removes the stacks only) |
| `receive_party` | crew: [snapshot] (logged as JSON text) | int (n spawned) | R4X: a recalled party walks back in near the HQ (cells via `sim.rng`, snapshots as `dispatch_party` gave them) |
| `receive_cargo` | items: {item: n} (logged as JSON text), radius: int | int (lost count) | R4b: spawns a crate near HQ (cell via `sim.rng`), ledger source `cargo`; items without room are recorded as `lost` |
| `set_patrol_route_text` | text: str ("x,y;x,y") | void | empty = automatic ring around the base |
| `purify_cell` | c: cell | bool | spends refined essence, cleans the field around c |
| `tutorial_ack` | - | void | R5 O1: view-mirrored confirmation (portrait selected, forecast opened, release tap); completes only an `ack`-type step. No-op unless `opts.tutorial` |
| `tutorial_skip_step` | - | void | completes the current step without its condition (still runs the next step's entry, e.g. arms the audit) |
| `tutorial_skip_all` | - | void | step = 12, `skipped` = true, `tutorial_finished` emitted once |

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
| `balance.json` | ticks_per_day, automation, map{width,height,clusters}, colony{colonists,engineers,start_items,start_stockpile_size}, colonist, mining, construction, waves..., `q_enabled`; `quests.json` (Q0: id -> {trigger, start, beats{text,then,options,effects}}, `quests_q*.json` merged) |
| `quests.json` | Q0 quest lines (`quests_q*.json` merged), gated by balance `q_enabled` |
| `biomes.json` | biome id -> {resources, purity_weights, node_density, hazard, yield_mult, refining_allowed}; R4: start, ash (cinder_ore), crystal (prism_ore), swamp (bog_resin) |
| `buildings.json` | id -> {name, size[2], color, max_hp, cost{item:n}, buildable, shelter, critical, threat, repair_cost{item:n}, decoy{fuel_item,burn_ticks,unlit_mult,pollution_per_burn,burst_mult,burst_ticks,cooldown_ticks,essence_item,essence_cost}, ...} |
| `contracts.json` | first_offer_day, offer_interval_days, offer_ttl_days, max_open, anger, templates[] |
| `crafting.json` | modes[], priorities[], default_priority, default_bill_target |
| `crises.json` | settings{}, crises id -> {options...} |
| `debt.json` | item, debt_min/max, due_days, despair_*, riot/escape tuning |
| `ecology.json` | nests_min/max, absorb_rate, bank_cap, starved_max, unit_cost{}, rally_ticks, chip_pressure, variant_bands[] (T5) |
| `enemies.json` | id -> {name, max_hp, move_ticks, damage, attack_cooldown_ticks, attack_range, threat_cost, variants{id->{hp_mult,damage_mult,move_ticks_delta}}} |
| `event_chains.json` | random_enabled, chance, steps[], complication, inspection_quota_default |
| `fuels.json` | L5 power fuels: threat_idle_mult, fuels{coal,nitrogen,uranium -> tier, generator, tech, energy_per_unit (= power_gen*burn_ticks/TPS), waste_per_unit, threat, spent_item/spent_per_burn, meltdown{}}, solar{}; buildings carry `power_use` (consumer), `power_gen` + `fuel{item,burn_ticks,waste_per_burn,spent_item?}` (generator, `fuel:null` = passive), `power_range` (pole); research `unlocks.belt_nodes`; `balance.json` keys `logistics2`, `power`, `map.extra_share` (biome `extra_resources` conversion, 0 = off); resources `appended: 2` = byte order after R4a |
| `events.json` | id -> {weight, min_day, harmful, max_per_game, requires, text, ...} |
| `events_prison.json` | same schema as events.json |
| `fx.json` | view-only juice (bursts, splats, drips, AUDITED text); not read by sim |
| `flavor.json` | view-only text bank (F1): dotted key paths -> arrays of lines; never read by sim |
| `expedition.json` | campaign: travel_ticks, map_size, buffer_cap, rate_ticks, upkeep, collateral, raid_*, flush_radius (read by Campaign/Autopilot; upkeep item = `raw_food`; sling numbers live on the `sling` building def) |
| `health.json` | parts, kinds, pain_scale/weight, downed_consciousness, shelter_collapse |
| `idle_work.json` | cleanup{}, patrol{}, training{} |
| `items.json` | id -> {name, color, stack, value} |
| `jobs.json` | flee/repair/operate/haul/mine tuning |
| `meta.json` | legacy, next_batch, scout_cells, unlocks (cross-run meta, enters the sim via `opts`) |
| `presets.json` | default, order, presets{id: name, sentence, wave_strength_mult, waste_mult, starting_debt_mult, crate, hint_density} (O3; become opts `wave_mult`, `waste_mult`, `debt_mult`, `crate`, `hint_density` via `StartOpts.preset_opts`; neutral values emit no key, so standard_term = `{}`) |
| `petitions.json` | preset_mult + phases[] {id,title,parts,reward{debt_cut_pct,items,unlock_tier},letter} (E1, gated by balance e1_enabled) |
| `quests_q2.json` | Q2 Pilgrims of the Slag: trigger pollution_min, zealot, beats/options (gated by balance q_enabled) |
| `shuttle.json` | preset_mult, gantry, parts_need, part_cost, countdown_days, siege_* numbers, repair_cost, win_letter (S1, gated by balance s1_enabled) |
| `milestones.json` | tiers id -> {parts{item:n}} audit deliveries per tier |
| `beacons.json` | S2: building, build_ticks, cost, life_days, cut_pct, diminish, cap_pct, max_alive (gated by balance s2_enabled) |
| `models.json` | art model descriptors (view only, not read by sim) |
| `mood.json` | base, check_ticks, thresholds, chances, thoughts |
| `quests_q1.json` | Q1 Clerk's Margin Note: tag, trigger, debt caps, loophole/report tuning, beat texts |
| `mutation.json` | update_ticks, cap, diffusion, decay, bloom/illness chances |
| `threat.json` | enabled (threat_v2), d0, k_poll, stick, pull_ratio, region_size/cap_per_region, recompute_ticks, base/state_mod/colonist_mod/species_bias; def fields `threat`, `threat_mods`; API `ThreatSystem.pick_target(e)`, `Building.threat_now(sim)`, `Building.threat_flags`; C2 `sim.abilities.flags_of(colonist_id)` {flag: [until_tick, mult, radius]} (kept off `Colonist`: its property list feeds golden dumps) multiplies `ThreatModel.colonist_value` (radius > 0: fades beyond it) |
| `names.json` | names[], backstories[] |
| `needs.json` | start_food/rest, retry_ticks, food{}, rest{} |
| `perks.json` | caps, respec_cost, perks id -> {skill, level, effect}, levels_per_point |
| `plants.json` | id -> {item, yield, grow_ticks, sow_ticks, harvest_ticks, min_daylight} |
| `quests_q6.json` | Q6 quest defs (QuestLog-merged, gated by q_enabled) |
| `quests_q10.json` | Q10 Maintenance Window quest defs (QuestLog-merged) |
| `quests_q3.json` | Q3 Parole Board quest defs (QuestLog-merged) |
| `quality.json` | tracked, skill, levels, thresholds, base, per_level, noise |
| `raids.json` | id -> {min_points, weight, spawn, retreat_fraction, units[]}; `scripted` raids (O1 `tutorial_audit`: fixed[], wave_ticks, hq_immune, colonist_harmless) are never rolled |
| `tutorial.json` | R5 O1: settings{audit_step, audit_delay_ticks}, steps[12] -> {id,title,text,reason,target{kind,id},done{signal,count/min_cells/where/or/latch},nudge_ticks} |
| `recipes.json` | id -> {name, inputs{}, outputs{}, work_ticks, station} |
| `research.json` | techs id -> {name, tier, prereqs[], cost{essence}, bench_ticks, unlocks{buildings,recipes,rules}, waste_mult} |
| `chips.json` | T4: item, tech, recipe, chip_speed 0.8, chip_threat_mult 2.0, chip_waste_mult 1.3, upkeep_item/upkeep_per_day, calibration_days 3, calibrate_ticks, calibrate_min_skill (operating) |
| `resources.json` | id -> {item, tier, biomes, base_rate, purity_mult, appended?}; `appended` resources get node_res bytes after legacy ones (keeps start-map hashes) |
| `rules.json` | id -> {name, default: bool (or mode string when `modes` present), hidden?, ...} player rules (`set_rule`) |
| `skills.json` | max_level, xp_base, xp_step, xp_per_work_tick, speed_per_level, passion_xp |
| `time.json` | start_hour, dawn/dusk hours, night_daylight |
| `roles.json` | C1: max_size, hold_search_radius, slot_spread, affinity{skill_weight,trait_weight}, order[], roles id -> {name, weapon, dmg_taken_mult, threat_mult, formation_offset, affinity_skill, ability} |
| `traits.json` | traits id -> {effects, role_affinity? {role: bonus}} |
| `weapons.json` | combat{}, weapons id -> {damage, range, cooldown, ...}, C2 `abilities` id -> {role, cooldown_ticks, essence_cost, contam_puff, noise_burst{mult,ticks}, taunt/volley/radius} |
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
- `opts`: `scout`, `site`, `crate` (item->count), `wave_mult` (raid points x), `waste_mult` (contamination x), `debt_mult` (starting debt x), `hint_density` (ignored by sim), `map_w`, `map_h`, meta unlock flags; consumed by `StartOpts.apply` and part of the replay input.

### 7b. Campaign save v3 (`SaveGame.campaign_to_dict`, R4 expeditions)
Sim saves stay v2. A campaign save is `{version:3, campaign_seed, defs_hash, tick, active, log, maps, ledgers, in_flight}`;
each map `{id, biome, kind, seed, opts, sim_commands, sim_tick, crew_n, dead_charged, sling_ready}` is replayed standalone to `sim_tick`
(the v2 replay), ledgers/in_flight/log are restored verbatim as plain data (whole floats back to int). A v2 file loads with error `"version"`.
`in_flight` entries: crate `{kind:"crate", from, to, items, arrive}`, party `{kind:"party", map_id, biome, crew, supplies, arrive}`,
return `{kind:"return", from, crew, items, arrive}`. Arrival = send tick + `travel`/`travel_ticks`, exact. Collateral: each dead crew member
(or whole crew of a lost outpost) adds `collateral` to `ledgers["campaign"].collateral_debt`, once. Tech `expeditions` (tier 2) gates `Expedition.send`.

### 7c. Campaign (`sim/campaign/campaign.gd`, R4X integration)
`Campaign.new(seed, bus_factory: Callable, defs = null, opts = {})`, then `start()` (home = map 0, `Simulation.new(seed, bus, defs, opts.home_opts)`, so it equals a plain sim);
`SaveGame.campaign_from_dict` builds it without `start()` and overwrites `maps, tick, active, campaign_seed, log, in_flight, ledgers`. `bus_factory` is called home-first, once per map.
Map ids are stable (a recalled outpost leaves a gap); use `entry(id)` / `Expedition.map_entry`, never list indices. `step()` = `tick += 1`, active sim `step()`, Autopilot day for unattended outposts
(`tick % ticks_per_day == 0`), `Expedition.tick`, `Sling.tick`. Commands (logged to `log` only when they succeed): `send_expedition(biome, ids, supplies)`, `recall(id)`,
`sling_send(0, items)` (fires from the ACTIVE outpost; its sling + stored items), `switch_map(id)`. Active-map arrivals go through sim commands (`receive_cargo`/`receive_party`); otherwise they wait in the
target ledger (`inbox`, `returning_crew`) and `switch_map` flushes them. `state_hash()` canonicalises dictionaries (sorted keys), so it survives a JSON save round trip.
Collateral debt is a counter (`ledgers["campaign"].collateral_debt`) because `sim/debt` has no add-debt API (it is per-colonist, drawn at join).

## 8. `state_hash` (`SaveGame.state_hash(sim)`)
An `int` hash of observable state. Parts in order: `[tick, game_over_reason, alarm]`; each `items.stacks` entry `[cell, stack]` (insertion order);
each colonist in `colonists.list` `[id, cell, hp, alive, carry_item, carry_count, carry_quality, learned_perks]`; each building in `buildings.list`
`[id, def_id, cell, hp, condition, broken, input, output, output_q]` and again `[..., output, ammo, ammo_policy]`; `hash(mutation.field)`;
`logistics.state_parts()` = `[belt_count, belts.state_hash()]`. Belt hp joins the hash only for tiles with hp != max (undamaged belts hash as before). `abilities.state_parts()` (cooldowns, threat flags, volley shots) is appended only after the first `use_ability`.

### Belt nodes (L1, `BeltGrid.kind`)
`kind` 0 plain, 1 splitter_basic, 2 splitter_smart, 3 splitter_priority, 4 merger (1x1 cells in the belt grid, `dir` = flow). API: `place_node(kind, cell, dir)`, `remove_node(cell)`, `set_filter(cell, slot, value)` (smart only; slot 0 left, 1 front, 2 right; `"any"|"overflow"|item`), `get_filter`, `node_kind`, `node_count`. Basic: round-robin pointer over free outputs; priority: front, left, right first free; smart: explicit item match, then `any` (round-robin), then `overflow`; merger: round-robin among ready facing inputs (back, left, right). Version bumps on place/remove/filter change. `belts.state_hash()` includes node state only when `node_count > 0` (goldens unchanged).
### Line damage (T3, `balance.json` `line_damage`)
`BeltGrid.hp` dense PackedFloat32Array (max `belt_hp`); hp < `stall_frac` x max: tile stops moving items; hp 0 stays as a broken marker (belt kept) until repaired. Creatures bite adjacent belt tiles (`structure_dmg` in `enemies.json`, own `bite_cd`, hook `ThreatSystem._attack_structure`). Machines get `broken` below `machine_broken_frac` hp. `RepairJob` (building or `RepairJob.for_belt(cell)`, reservation `rep:belt:x,y`) pays `belt_repair_cost`/`machine_repair_cost` (building def `repair_cost` overrides) from stored items, only for structural damage; the giver offers it only if affordable.
(GD) Today it is `var_to_str(parts).hash()` (Godot text serialisation, 32-bit string hash): engine-specific, a port cannot match it bit for bit. Portable definition for cross-engine comparison: canonical JSON of the same parts (UTF-8, no whitespace, sorted keys, shortest round-trip floats, cells as `[x,y]`) fed to a stable hash such as FNV-1a 64; switching changes every golden (`tests/golden/`, R1b), so it is deferred.
Not covered by the hash today (known gaps): needs, mood, skills/xp, injuries, contamination levels, bills, contracts, debt, enemies, rng state.

## 9. Architecture constraints a port must keep
`sim/` has no rendering, Node, scene tree or autoload lookups; the view only reads state, listens to the bus and issues commands through `Simulation` methods.
Systems are modules (`core, map, colonists, jobs, items, buildings, contamination, threats, storyteller, ...`); systems read map/items, never the view.
Reachability: grid A* plus connected components (O(1) reachable test); equal-cost tie-break by neighbour order N,E,S,W. Job reservations use string keys; flee overrides all jobs while the alarm is on.

## 10. AI chip operator (T4, `sim.chips`)
A chip replaces the operator of a bench/smelter/assembler: bench adds `bench_rate * chip_speed` per tick without a colonist; a processor takes 4 of 5 work steps (accumulator, no rng).
Waste of a chip building is scaled by `chip_waste_mult` (fraction rolled on `sim.rng`, only with a chip, so chipless games are unchanged). Upkeep: `upkeep_per_day` refined essence
at each day start (retried every tick while unpaid; unpaid = chip stops). Calibration is due `calibration_days` after install/last calibration; then the chip stops until a colonist
with `operating` >= `calibrate_min_skill` runs `CalibrateJob` (`calibrate_ticks` ticks on site). A broken or destroyed building drops its chip.
Read-only API for the threat system: `chips.threat_mult(building)` (`chip_threat_mult` while the chip is busy, else 1.0) and `chips.colony_threat_mult()` (max over busy chips).
`ai_chip` is accepted by the stockpile zone; recipe `make_ai_chip` (assembler) needs tech `ai_chips`. Chip state is not in `state_hash`; it is rebuilt by command replay.

## T5 ecology (summary)
Nests (2-4, map edge, reachable) are placed from the ecology stream at `start_new_game`. Every `update_ticks` each nest banks
`pollution_at(nest) * absorb_rate * dt * chip_pressure` (local mutation field + planet level), capped. A raid keeps `starved_max` units free and
pays `unit_cost` per further unit from the banks, dropping what it cannot afford; waves leave from the fullest nest. `letter_received`
"Creatures are massing" fires `rally_ticks` before the wave. Mutant variants roll per unit from the nest's pollution tier (hysteresis `revert_ratio`).

## 12. Squads (C1, `sim.squads`, `sim/squads/`)
`SquadSystem` (list of `Squad`, ascending id) keeps `members`, `role_of`, `hold` anchor, `focus` enemy id. No rng. `tick()` runs after `threats.tick()`: when a focus target is gone, focus clears and members return to their slots.
Role = `data/roles.json`; auto-suggest `suggest_roles(ids)`: score = skill level (`affinity_skill`) x `skill_weight` + trait `role_affinity` x `trait_weight`; distinct roles are filled first (best score, ties lower id).
Commands are logged as text for arrays (`form_squad("[1,2]", "[]")`). Death removes a member (empty squad is deleted). Manual `order_*` on a member is allowed and wins until the next squad command. `state_hash` appends `squads.state_parts()` only while a squad exists (goldens unchanged). API for other workers: `get_squad(sid)`, `squad_of(colonist_id)`, `list`, `Squad.role_of[id]`.
## 11. Warden's Orientation (R5 O1, `sim.tutorial`, `sim/tutorial/tutorial_system.gd`)
Exists only with `opts.tutorial == true` (else `sim.tutorial == null`, commands are recorded no-ops, hashes unchanged). No rng. Runs last in `step()` (after `storyteller.tick`, before the colonists-dead check); `sim.in_step` is true during `step()`.
State: `step` (0..12, 12 = finished), `done[]`, `skipped`, `ticks_in_step`, `seen[]` cells, per-step flags, latched facts; appended to `state_hash` only in tutorial mode. Bus: `tutorial_step_changed(step)`, `tutorial_finished()`.
Each step advances only on its `done.signal` (ack command, 3 mine designations, 4 zone cells, 10 stored ore after `item_mined`, workbench/refinery placed, `first_refine_done`, `research_completed`, >=3 belts + an item arriving in a port building, `forecast_revealed` or ack, `wave_repelled` with player alarm or a turret, decoy placed or `wave_incoming`, ack).
Normal waves are held (`waves_held()`) until the audit step; entering it calls `threats.schedule_scripted(delay)`: raid `tutorial_audit` (2 crawlers, 1800-tick limit, always counts as repelled, pod takes 0 damage, inmates take 0 damage). View API: `current()`, `progress()`, `nudge_due()`, `is_done(id)`, `finished()`, `step_count()`.
## 12. Health bands (C4)
`HealthState.band(cfg)` / `sim.health.band(c)` derives `fit | wounded | down` from the existing model (down = `downed`; wounded = blood < `band.wounded_blood` or total damage >= `band.wounded_damage`). `sim.health.bleed_out_seconds(c)` = ceil(blood / bleed_rate / TICKS_PER_SECOND) while Down and bleeding, else -1. `sim.health.stabilise(c, medic)` tends all injuries at `band.stabilise_quality` (C2 Medic hook). Auto-rescue is the existing `RescueGiver` (any colonist with doctoring enabled carries a Down colonist to a free bed). No new RNG, no goldens change (derived reads only); data in `health.json` `band`.
## C3 telegraphed attacks (`ThreatSystem` region C3)
`data/enemies.json` `telegraph {windup_ticks, shape cell|line|area, radius|length, dmg_mult}` (brute area r1/20, spitter line 6/14, burrower cell/24, crawler none). When an enemy in range would strike, it stands still, locks the marked cells (`e` meta `tg`, no rng) and after `windup_ticks` hits every colonist/the target building still inside them; units that left are untouched. A killed enemy cancels its strike. `telegraphs()` (view) and `telegraph_state()` (appended to `state_hash` only while a wind-up is active).
## F1 Flavor text bank (`view/flavor_picker.gd`, `data/flavor.json`)
View-side only: no sim state, no `sim.rng`, not in `state_hash`/saves, goldens unaffected. `FlavorPicker.load_bank()` (alias `load_default()`), `pick(key, ctx)`, `pick_first([keys], ctx)`, `has_key`, `all_keys`, `K_*` key constants. Keys are dotted paths (`feed.<enemy>.<cause>`, `pa.<signal>`, `barks.<state>`...). ctx: `tick`, `id` (seed = hash([tick,key,id])), placeholders `who victim enemy n cause`. Ring of last 4 lines per key is picker state.
## L3 Power (`sim.power`, `sim/power/`, API in `docs/power_api.md`)
Off (factor 1, no hash part) until a pole/generator exists; networks = union-find, rebuilt on `buildings.version`; factor = clamp(supply/demand, 0.2, 1); no pole in range = 0.5; fuel from `data/fuels.json`; deterministic, no rng.
