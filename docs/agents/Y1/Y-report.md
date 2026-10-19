# Y1 report: nitrogen on the home map
Change: `data/biomes.json` start biome `guaranteed_nodes: {nitrogen: 2}`; `MapGenerator._guarantee_nodes` (region Y1, after L5) converts 2 deposit blobs (iron/copper first, essence last; farthest from HQ first; not near start, not coal) to nitrogen. No rng use, only `node_res` changes (tiles/amounts/purity identical, map hash unchanged). Nearest-first was tried and broke goldens/chain/tutorial tests; farthest-first leaves near ore intact.
Tests: new `tests/test_y1_nitrogen.gd` (1-2 nitrogen blobs on seeds 1-5, deterministic, reachable from HQ); `test_u4_factory_bot` inverted (home map HAS nitrogen). Sharded suite: 770 passed, 0 failed.
Goldens: NOT regenerated, none changed (tick-identical; only node_res changed and sim goldens do not mine those cells). Changed ticks: none.
Pillar table (kx) before == after: baseline 6.4 waves, throttle 4.2, mining 4.0 (deaths 0). Threat bench unchanged.
Factory bot 60 d (nitrogen_nodes = cells, was 0 on all seeds; now 15/14/13/11/11):
| seed | before (alive / end / plate / ore prod) | after |
|---|---|---|
| 1 | 8 / survived / 16 / 1540 | 8 / survived / 16 / 2356 |
| 2 | 0 / colonists_dead / 8 / 969 | same |
| 3 | 6 / hq_destroyed / 4 / 1558 | 5 / hq_destroyed / 4 / 1058 |
| 4 | 0 / colonists_dead / 9 / 1180 | 0 / colonists_dead / 9 / 1196 |
| 5 | 0 / hq_destroyed / 7 / 721 | same |
Bot still has no P1-P4/parts (audit2 blocked by plates/parts, Y2/Y4 work); the nitrogen blocker itself is removed: bot (Y4) can now place nitrogen_extractor on the node.
Files: data/biomes.json, sim/map/map_generator.gd, tests/test_y1_nitrogen.gd, tests/test_u4_factory_bot.gd.
