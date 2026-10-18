# A1a report (resource nodes)
- Branch: worktree-agent-a124555a548f5ecb9 (not pushed).
- Nodes live on DEPOSIT tiles (solid, mined from adjacent ground) -> pathing/designation unchanged.
- MapGrid (region A1a): node_res, node_purity, node_carry arrays, biome_id, is_node/node_resource/node_cells/mine_node;
  take_from_deposit is a compat shim (nodes return full amount, never deplete); checksum includes nodes.
- New sim/map/node_data.gd (NodeData: loads data/resources.json + biomes.json, purity mult, rate).
- data/resources.json (essence/copper/iron, base_rate 10, purity 0.5/1/2), data/biomes.json ("start"), balance map.start_biome.
- MapGenerator: one resource per cluster (weighted), purity per node; deposit_amount = 0 for nodes. RNG stream changed, so seeds differ from before.
- MineJob: node yield = balance mining.yield * purity_mult (fraction carried per node => exact 1:2:4); designation clears after each cycle (re-designate to repeat). Item falls back to essence_ore while copper_ore/iron_ore are missing from items.json (A1b adds them).
- tests/test_nodes.gd: 5 tests pass.
## Full suite: 341 pass, 5 fail (all migration/balance fallout, need A1e)
- test_mining deposit accounting (expects finite deposit_amount), test_storyteller cave_in accounting (retarget to nodes),
  test_waves x2 (essence income now split across copper/iron until recipes use them; seed RNG shifted),
  test_ui_perks::test_learn_through_ui (seed 5 colonist changed by new RNG stream; likely seed-sensitive).
- Not verified against baseline (stash was denied).
