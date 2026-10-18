# R4 W1 report

Branch r4-w1. Added biomes ash/crystal/swamp (data/biomes.json, resources.json, items.json), fields yield_mult/refining_allowed on all biomes.
- Resources cinder_ore/prism_ore/bog_resin marked "appended": NodeData assigns their node_res bytes after legacy ones (region R4a in sim/map/node_data.gd) so start-map hashes/goldens stay identical.
- map_generator.gd needed no change: it already reads cfg.start_biome (opts override is W2).
- tests/test_biomes.gd: seeds 1..5 x 3 biomes, >=4 nodes, no foreign nodes, determinism, gen time, legacy bytes, defs validate.
- docs/sim_contract.md rows updated.
- Full suite: 464 pass, 3 fail (known: test_golden, test_waves x2).
