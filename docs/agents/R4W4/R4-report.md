# R4-W4 report (expedition, sling, save v3, research gate)
Branch `r4-w4` (base 0cbc1b6). Files: sim/campaign/expedition.gd, sim/campaign/sling.gd, save_game.gd (region R4d), data/research.json
(tech `expeditions`, own block), data/buildings.json (`sling`), data/rules.json (hidden rule `expeditions`, needed by the tech unlock),
tests/stub_campaign.gd (W3 stand-in), tests/test_expedition.gd, test_sling.gd, test_campaign_save.gd, docs/sim_contract.md (7b).

## Exact calls W3 (Campaign) must make
- `send_expedition(biome, ids, supplies)`: log campaign command, then `Expedition.send(self, biome, ids, supplies) -> bool`.
- `recall(id)`: `Expedition.recall(self, id) -> bool`. `sling_send(id, items)`: `Sling.send(self, id, items) -> bool`.
- In `step()` after `tick += 1` and the active sim step: `Expedition.tick(self)` then `Sling.tick(self)`.
- Campaign must expose plain fields: `maps` (entries {id,biome,sim,kind}), `tick`, `active`, `campaign_seed`, `log`, `in_flight`, `ledgers`, `defs`, `bus_factory` (Callable -> bus).
- `SaveGame.campaign_from_dict(data, bus_factory, defs)` does `Campaign.new(seed, bus_factory, defs)` (no `start()`), then overwrites the fields above.
- Ledger keys: ints (strings tolerated); `ledger.inbox`/`buffer` = {item:n}; `ledger.lost` bool = lost outpost. switch_map must flush `inbox`.
- Map entries get extra keys `crew_n, dead_charged, sling_ready, seed, opts` (saved).

## Hooks used from W2 (has_method guarded; absent -> action refused / items go to inbox)
`home.dispatch_party(ids, supplies) -> Dictionary` (expects `{ok:bool, crew:Array}`; empty dict = refused), `sim.dispatch_party([], items)` reused for sling removal,
`receive_cargo(items, radius)`, optional `receive_party(crew)` (recall), optional `charge_debt(n)` (collateral; counter in ledgers["campaign"] regardless).

## Status
New tests pass (14). Tests that need `dispatch_party` (send with tech, sling send/cooldown) return early on this branch until W2 merges: re-run after merge.
Gating is strict: `research.is_done("expeditions")` (ignores the `gating` switch). Defaults for travel_ticks/collateral/map size are a FALLBACK in expedition.gd
until W3's data/expedition.json exists. Full suite: see commit message / orchestrator run.
