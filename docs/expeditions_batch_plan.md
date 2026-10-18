# Batch R4 "Expeditions: campaign of maps" - plan (prompter)
Base: dev branch AFTER the R3 wave merged. One wave, 5 Sonnet workers, disjoint files; shared files only in `# region <agent>`.
Report each worker: `docs/agents/<agent>/R4-report.md` (<= 30 lines). `sim/` stays deterministic; full suite green; no push.

## Design (decided without owner, review - log in DECISIONS.md)
- **Campaign layer**: `sim/campaign/campaign.gd` (RefCounted, no Node). Holds `maps: Array` of `{id:int, biome:String, sim:Simulation, kind:"home"|"outpost"}`,
  `active:int`, `tick:int`, `campaign_seed`, `log:Array` of `[tick,name,args]`, `in_flight:Array` (sling crates), `ledgers:Dictionary`.
  Home is map 0 and uses seed = campaign_seed, so `Campaign.new(s)` home == `Simulation.new(s)`: ALL existing goldens/tests unchanged.
  Outpost k seed = `campaign_seed * 1000003 + k * 7919` (int math, no hash()). Each sim gets its own bus instance passed in by the caller.
- **Only the active map runs real `step()`.** `Campaign.step()`: `tick += 1`; active sim `.step()`; then `Autopilot.advance(...)` for every other map (O(1)); then sling arrivals.
  Why not 1 step per N ticks: still costs N-times CPU per map, and its state drifts from "same rules"; analytic keeps 3 maps = 1 real sim of cost.
- **Autopilot (analytic, per map-day)**: at each `ticks_per_day` boundary an unattended outpost computes
  `yield = sum(miners_assigned * resource.base_rate * purity_mult * biome.yield_mult) * day_ticks/rate_ticks`, minus upkeep (`food`/`supplies` from ledger),
  adds to its `ledger.buffer` (capped by `buffer_cap`); one raid roll from its OWN stream `seed ^ 0x0A07` against `biome.hazard` -> damages ledger `integrity`,
  at 0 the outpost is "lost" (crew counted as dead, debt collateral charged). Switching INTO a map flushes `ledger.buffer`+`inbox` into the sim as recorded
  sim commands (`receive_cargo`), then it runs real steps; switching OUT snapshots miner count/node list into the ledger. No catch-up stepping.
- **Expedition**: `Campaign.send_expedition(biome_id, colonist_ids, supplies:{item:n})` (recorded campaign command, needs tech `expeditions`): home sim command
  `dispatch_party(ids, supplies)` removes colonists/items (recorded in home log); after `travel_ticks` (data) the outpost sim is created
  (`start_new_game` with opts `{map_w:96,map_h:96,biome,crew:[snapshots],supplies,no_refining:true}`) and appended to `maps`. Each crew member carries
  `collateral = debt_share` (data); death/loss adds it to home debt via bus `expedition_loss`. `recall(map_id)` returns survivors+buffer by a timed trip.
- **Sling cargo**: outpost building `sling` (data) with `capacity` items per shot and `cooldown` ticks; `Campaign.sling_send(map_id, items)` queues a crate
  `{from,to,items,arrive=tick+travel}`; on arrival at the active map -> sim command `receive_cargo(items, seed_cell)` (spawn crate within radius R of HQ via sim.rng,
  item stack lost if no room, uses `drop()`); not active -> `ledger.inbox`. Max in flight and capacity capped by data.
- **Biomes** (data): `ash` (cinder_ore, hazard 2, yield_mult 1.2), `crystal` (prism_ore, hazard 1, purity skew pure), `swamp` (bog_resin, hazard 3).
  Tier-2 elements; each needs a home-only recipe station (forge site rule): part X craftable only if its element was shipped in.
- **Save v3**: `{version:3, campaign_seed, defs_hash, tick, active, log, maps:[{id,biome,seed,opts,sim_commands,sim_tick}], ledgers, in_flight}`.
  Load = replay each sim standalone to its `sim_tick` (existing v2 `_replay` per map), then restore ledgers/in_flight verbatim (plain data, not replayed).
  v2 single-map saves: `load` returns error `"version"` (accepted) UNLESS wrapped: v2 -> Campaign with 1 map is NOT required.
- **Perf**: home 250x250 keeps the P1 budget; outposts are 96x96 (<= 9.2k cells). 3 maps: `Campaign.step()` <= active-step + 0.15 ms avg; memory +<= 25 MB.

## Interfaces (all workers code against these exactly)
`Campaign`: `new(seed, bus_factory:Callable, defs=null, opts={})`, `start()`, `step()`, `active_sim()->Simulation`, `switch_map(id)->bool`,
`send_expedition(biome,ids,supplies)->bool`, `recall(id)->bool`, `sling_send(id,items)->bool`, `map_info(id)->Dictionary`, `state_hash()->int`.
`Simulation` new recorded commands: `dispatch_party(ids:[int],supplies:Dictionary)->Dictionary`, `receive_cargo(items:Dictionary,radius:int)->int`.
Signals on bus (`autoload/event_bus.gd` region R4): `map_switched(id)`, `expedition_sent(id)`, `expedition_arrived(id)`, `expedition_loss(id,debt)`, `cargo_arrived(id,n)`.

## W1 biomes (data + generator)
Owns `data/biomes.json`, `data/resources.json`, `data/items.json` (region R4a), `sim/map/map_generator.gd` (region R4a), `tests/test_biomes.gd`.
Adds 3 biomes above; `cfg.start_biome` overridable by opts; fields `hazard,yield_mult,refining_allowed`.
Accept: seeds 1..5 x 3 biomes generate on 96x96 with >= 4 deposit nodes of the biome's resource each, 0 nodes of other biomes; same seed -> equal `tiles`/`node_res`
arrays; `start` biome output byte-identical (existing goldens green); generation <= 40 ms for 96x96.

## W2 sim hooks
Owns `sim/core/simulation.gd` (region R4b), `sim/meta/start_opts.gd` (region R4b), `tests/test_sim_hooks.gd`.
opts `biome`, `crew`, `supplies`, `no_refining`: crew replaces `_place_starting_colony` (names/skills copied, 0 rng calls beyond fixed count); `place_building` refuses
refinery-class buildings when `no_refining`; commands `dispatch_party`, `receive_cargo` (recorded first line, failed = no change). Add rows to `docs/sim_contract.md`
command table (keep `test_contract_doc` green).
Accept: dispatch removes exactly n colonists + supplies, rejects ids not alive or supplies not owned (no state change, state_hash equal); receive_cargo of 20 items
lands 20 on map or records lost count; replay with these commands gives equal state_hash; default start (no new opts) golden hashes unchanged.

## W3 campaign + autopilot
Owns `sim/campaign/campaign.gd`, `sim/campaign/autopilot.gd`, `data/expedition.json` (travel_ticks, buffer_cap, upkeep, collateral, sling stats, map size), `tests/test_campaign.gd`, `tests/test_autopilot.gd`.
Accept: `Campaign.new(7)` home `state_hash` after 600 steps == plain `Simulation(7)` after 600 steps; outpost seed formula; switch_map recorded and replay-equal;
2 same-seed campaigns with identical command lists have equal `state_hash` after 3000 ticks (3 maps); autopilot: 5 miners on 'pure' nodes for 10 days yield
within +-0 of the formula (exact, deterministic) and buffer never exceeds `buffer_cap`; raid roll never touches `sim.rng`; 3-map campaign step cost <= +0.15 ms avg (bench in test, 600 ticks).

## W4 expedition, sling, save v3, research gate
Owns `sim/campaign/expedition.gd`, `sim/campaign/sling.gd`, `sim/core/save_game.gd` (region R4d: `campaign_to_dict/campaign_from_dict`, VERSION constant for sim saves stays 2),
`data/research.json` (add tech `expeditions`, tier 2, prereq an existing tier-1 tech, unlocks rule `expeditions`), `data/buildings.json` (region R4d: `sling`),
`tests/test_expedition.gd`, `tests/test_sling.gd`, `tests/test_campaign_save.gd`.
Accept: `send_expedition` false without tech; with tech + 3 colonists + supplies: home colonists -3, outpost appears after exactly `travel_ticks`; crew death charges
`collateral` x n to home debt exactly once; sling crate of capacity items arrives after `travel` ticks +-0, over-capacity rejected, in-flight crates survive save/load;
save v3 mid-trip (crate in flight + party travelling) load -> `state_hash` equal at same tick and equal after +500 ticks; v2 JSON -> error `"version"`.

## W5 view + UI (touch-first, English)
Owns `view/game.gd` (region R4e), `view/panels/map_switcher.gd`, `view/panels/expedition_panel.gd`, `view/hud.gd` (region R4e), `autoload/event_bus.gd` (region R4, signals above),
`tests/test_expedition_ui.gd`. `GameController` holds a `Campaign` (new game and loaded save), `sim` var always = `campaign.active_sim()`; on `map_switched` rebuild `WorldView`/camera for the new map.
Map switcher: top-bar chips (>= 64 px), one per map, badge for in-flight cargo / alarm on unattended map. Expedition dialog: pick biome (locked with reason if tech missing) ->
pick colonists (checkboxes) -> pick supplies (+/- steppers) -> confirm showing travel time and debt collateral -> result letter on arrival/loss.
Accept: headless UI test builds panel, every button min size >= 64 px, flow plan->confirm calls `send_expedition` once; switching maps swaps `game.sim` and WorldView map size (250 -> 96);
no hover/right-click; save/load restores active map; screenshot of both maps by the orchestrator.

## Merge order and risks
W1, W2 first (data/hooks), then W3, W4, W5 (they stub missing hooks with `has_method`). Risks: bus per map (events must not cross maps - test: outpost raid never emits on home bus);
`GameController` still owns speed, calls `campaign.step()`. Out of scope: factions, trade, outpost refining, tutorial (R5).
