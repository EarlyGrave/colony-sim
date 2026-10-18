# A1b report (items/data/defs)
- items.json: copper_ore, iron_ore, ingot_copper, ingot_iron, plate, parts (English names).
- recipes.json: new `station` list (building ids). refine_essence got station [refinery, smelter];
  new smelt_copper, smelt_iron (waste 1 each), make_plate, make_parts (assembler). No `benches` on new recipes,
  so the bill UI is unaffected.
- buildings.json: miner (machine=extractor, on_node, 1 out port), smelter/assembler (machine=processor, station,
  in+out ports), storage_in/storage_out (port_building, buffer_capacity 200), belt (belt=true, no ports).
  All new ones `buildable:false` (A2 flips them when UI/logic exist). Ports: {dx,dy,dir N/E/S/W,kind in|out},
  offsets relative to the building origin. No power field (owner answer 1).
- Deviation: miner has only an out port (an extractor has no input); the "in+out" rule applies to processors.
- defs.gd region A1b: `resources`, `biomes` vars (loaded only if data/resources.json / biomes.json exist, so
  A1a's files plug in), duplicate_defs copies, and `validate() -> Array[String]` (recipe items/stations, waste on
  refining recipes, port dir/kind, machine ports, resource item, biome resources).
- tests/test_automation_defs.gd: 4 tests pass. Full suite result: see commit message / run log.
- No balance.json keys added; shared-file edits are only inside `# region A1b`.
- view/building_3d.gd line 12: new building ids added to FLAT_FALLBACK (one-line hook; test_building_3d required it). Full suite: 345/345 after this fix (344+1 verified individually).
