# Expeditions (campaign of maps) and ecology

## Campaign layer `[BUILT]` (R4) — `sim/campaign/campaign.gd`, `expedition.gd`, `sling.gd`, `autopilot.gd`, `data/expedition.json`, tech `expeditions`, rule `expeditions`
- Several Simulations under one clock; home = map 0 (seed unchanged, so a campaign home == a plain game).
  Only the active map steps for real; unattended outposts advance analytically once per day (`Autopilot`:
  yield by miners/purity/biome, buffer cap 400, upkeep food per miner, raid roll per hazard 0.15, integrity
  100, "lost" state). Map switcher in the HUD; save v3 (v2 loads as home only).
- **Expeditions**: `dispatch_party(ids, supplies, biome)` (travel 1200 ticks), crew carries debt
  collateral (100 per head charged on loss); `receive_party` on recall (Recall button). Outposts yield the
  tier-2 elements (cinder/prism/bog_resin); the matching parts are crafted only at home `[PARTIAL]` (resin
  feeds the cure; cinder/prism have no consumer recipe yet).
- **Sling cargo**: `sling` building (capacity, cooldown, travel, max in flight) throws crates home; land near
  the HQ within `deliver_radius`, `receive_cargo`. Deterministic (own stream).
- Ties: Frontier Quota contract (B4) needs an outpost; Parole Review "outpost held N days" step (K2);
  outposts are audit-patrol decoys and clean outposts are not raid magnets (`b2_clean_outpost`).
- Bot: expedition bot plays Frontier Quota on 3/5 seeds. Story hook Q5 "Outpost 7" `[IDEA]`.

## Ecology (nests) — summary; detail in [05-threats-combat/creatures-waves.md](../05-threats-combat/creatures-waves.md)
2-4 nests at the map edge with pollution-fed hunger banks; waves spawn at the fullest nest; mutant bands
by local pollution with hysteresis; rally letter 1800 ticks before a muster; dormancy after a repelled wave.
Nest "territory" that could be cleared or scrubbed `[IDEA]` (scout: dirty-ground ecology, scavenger species
on clean soil).

## Power on the map — summary; detail in [02-economy/resources-chains.md](../02-economy/resources-chains.md)
Coal / nitrogen / uranium nodes feed generators; spent fuel contaminates (half-life); solar is clean.
Vents (nitrogen) and irradiated (uranium) biomes exist for outposts; home guarantees 2 nitrogen nodes.

## Day clock `[BUILT]` — `sim/world/clock.gd`, `data/time.json`
600 ticks/day, start 06:00, dawn 5-7, dusk 18-20, night daylight 0.35; sleep thresholds differ by day/night;
Night Owl / Early Bird traits; plants need daylight.
