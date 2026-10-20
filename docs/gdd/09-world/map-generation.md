# Map generation, biomes, presets

## Home map `[BUILT]` — `sim/map/map_generator.gd`, `data/balance.json map`
- Default 64x64 (`map_w/map_h` start opts; web `?size=N` up to 250 for perf checks). Seeded from
  `sim.rng` (same seed = same map; `?seed=42`).
- Terrain: ground, rock clusters (16 regardless of size -> 0.8 % rock at 250x250, 2.5 % at 128), finite
  deposits (essence) near the start within `clear_radius`, infinite nodes (essence / copper / iron / coal /
  nitrogen / uranium) with purity; `extra_share` 0.35 converts some blobs to coal etc. never within
  `extra_min_distance` 13 of start.
- Guarantees (OS/YX passes): iron 1, copper 1, nitrogen 2, coal donors; never converts a resource's last
  blob; essence always reachable; `deposit_rings` carve rings so sealed copper/iron are reachable (PG);
  enclosed pockets opened. Changing these shifts goldens for the affected seeds (listed in reports).
- Pathfinding: AStarGrid2D + connected components for O(1) reachability; buildings walkable except walls;
  deposits/rock solid (D8); flow fields (bounded, LRU) + spatial hash for creatures.

## Biomes `[BUILT]` — `data/biomes.json`, `data/resources.json`
start (home), ash (cinder_ore), crystal (prism_ore), swamp (bog_resin), vents (nitrogen), irradiated
(uranium). Each: resources, purity weights, node density, hazard (raid chance for outposts), yield mult,
`refining_allowed`. Outpost maps are 96x96.

## Presets ("sentences") `[BUILT]` — `data/presets.json`, goldens per preset
| preset | sentence | waves x | waste x | debt x | audit every | calm after hit | hints |
|---|---|---|---|---|---|---|---|
| short_stay | 6 months | 0.6 | 0.45 | 0.7 | 8 d | 2.0 d | full |
| standard_term | 5 years | 1.0 | 1.0 | 1.0 | 6 d | 1.0 d | new |
| hard_time | life | 1.15 | 1.15 | 1.3 | 4.2 d | 0.4 d | off |
Also preset-scaled: petition amounts, shuttle parts (0.6 / 1.0 / 1.3), Parole Review steps (K2). NG+ steps
the preset up. Waves by d21: 4.8 / 6.6 / 7.2 (hard target 8 not met).

## Not built / ideas
- Caves, ruins, nest chambers worth surveying (would justify survey fog) `[IDEA]`.
- Local "scarred" tiles that permanently cost yield unless cleaned `[IDEA]` (the mutation field is the
  partial answer: crops suffer on tainted ground).
- Seasons/weather: covered by storyteller events + forecast (scout decision).
