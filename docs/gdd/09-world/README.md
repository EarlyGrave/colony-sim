# 09 — World

| file | content |
|---|---|
| [map-generation.md](map-generation.md) | map sizes, seeded generation, rock/deposits/nodes, guarantees and rings, biomes, presets |
| [expeditions-ecology.md](expeditions-ecology.md) | campaign layer, outposts & autopilot, sling cargo, expedition crews; ecology nests summary; power fuels on the map |

Code: `sim/map/` (MapGrid, MapGenerator, Pathfinder, GridMover, flow fields, spatial hash), `sim/campaign/`
(Campaign, Expedition, Sling, Autopilot), `sim/ecology/`, `sim/world/clock.gd`. Data: `data/balance.json map`,
`data/biomes.json`, `data/resources.json`, `data/expedition.json`, `data/presets.json`, `data/ecology.json`.
Scouts: [research_expeditions_ecology.md](../../scout/research_expeditions_ecology.md), [pacing.md §4](../../scout/pacing.md).
