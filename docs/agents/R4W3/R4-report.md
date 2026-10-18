# R4-W3 report: campaign + autopilot

Branch: r4-w3-campaign (from 0cbc1b6). Not pushed.

Delivered: sim/campaign/campaign.gd, sim/campaign/autopilot.gd, data/expedition.json,
tests/test_campaign.gd (7), tests/test_autopilot.gd (5). No shared files touched.

- Campaign.new(seed, bus_factory, defs, opts) + start(); home map 0 uses seed unchanged (state_hash == plain Simulation after 600 steps).
- Outpost seed = seed*1000003 + k*7919; each map gets its own bus from bus_factory.
- Only the active sim steps; other outposts get Autopilot.advance_day at tick % ticks_per_day == 0.
- Autopilot: pure functions over a plain-data ledger; yield = floor(miners*base_rate*purity*yield_mult*tpd/rate_ticks), upkeep gate, buffer_cap, stateless raid roll keyed (seed^0x0A07, day), never sim.rng; integrity 0 -> lost, collateral charged.
- switch_map logged [tick,"switch_map",[id]]; switching out snapshots miners, in flushes buffer+inbox.
- state_hash() covers tick, active, log, ledgers, in_flight and every sim hash.
- Bench: 3-map extra cost <= 0.15 ms/tick passes.

Stubbed hooks (has_method / has_signal / file-exists guards):
1. Simulation.receive_cargo (W2): flush skipped, cargo stays in ledger until it exists.
2. Simulation opts crew/biome/supplies/no_refining (W2): passed in opts, ignored by old Simulation.
3. Bus signals map_switched, expedition_loss (W5): emitted only if declared.
4. Campaign.send_expedition / recall / sling_send (W4): stubs returning false; W4 overrides.
5. res://sim/campaign/sling.gd process_arrivals(campaign) (W4): called if present and in_flight non-empty.
6. data/biomes.json hazard/yield_mult/resources and resources.json (W1): read from defs.biomes with defaults; tests inject their own.
7. Home debt: collateral tracked in Campaign.home_debt_charged only (no debt system API yet).

Full suite: see commit message / orchestrator run.
