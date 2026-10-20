# Resources and production chains

## Items `[BUILT]` — `data/items.json` (24 ids), `sim/items/item_system.gd`
One stack per cell; zones = storage (`data/zones.json`: stockpile, depot, waste_dump, growing); `drop()`
spills, records "lost" if no room; `Ledger` keeps `world == produced - consumed` (tests enforce it).
| group | items |
|---|---|
| essence | `essence_ore` -> `refined_essence` (+ `waste`), `essence_bloom` (rare, from mutated ground), `essence_rounds` (ammo), `cure` (Remission) |
| metals | `copper_ore`/`iron_ore` -> `ingot_copper`/`ingot_iron` -> `plate` (iron) -> `parts` (plate + copper ingot), `machine_parts` (hand-made early part) |
| power | `coal`, `nitrogen`, `uranium`, `spent_fuel` (contaminates, half-life), `fuel_cell` (nitrogen + plate, or dirty) |
| outposts | `cinder_ore` (ash), `prism_ore` (crystal), `bog_resin` (swamp) |
| other | `raw_food`/`meal`, `ai_chip` |
Design note: the E9 table (`docs/economy/resources-and-chains.md`: wood, stone, steel, circuits...) was never
built; the real chain is the shorter one above. Item ids `refined_essence`/`waste` are kept (D21).

## Resource nodes `[BUILT]` — `data/resources.json`, `data/biomes.json`, `sim/map/node_data.gd`
Infinite nodes with purity 0.5/1/2 (speed only). Home map guarantees iron 1 / copper 1 / nitrogen 2 and
coal donors (OS pass); copper/iron rings are carved so sealed deposits are reachable (PG pass).
Finite deposits (`designate_mine`) are the hand phase; nodes need a `miner`/`nitrogen_extractor`.

## Recipes `[BUILT]` — `data/recipes.json`, `sim/buildings/building_system.gd`, `sim/crafting/bill_system.gd`
| recipe | in -> out | station | pollutes |
|---|---|---|---|
| `refine_essence` | 10 essence_ore -> 6 refined + 4 waste, 100 t | refinery, smelter | **yes** (the only base one) |
| `fuel_cell_dirty` (C1) | 6 ore + 1 refined -> 1 fuel_cell + 3 waste, 60 t; tech `bulk_refining` | refinery, smelter | **yes** |
| `smelt_iron` / `smelt_copper` | 4 ore -> 2 ingots, 80 t | smelter | no |
| `make_plate` | 1 ingot_iron -> 1 plate, 60 t | assembler | no |
| `make_parts` | 1 plate + 1 ingot_copper -> 1 parts, 80 t (stock_cap 25) | assembler | no |
| `hand_plate` | 3 ore -> plate (workbench, no research) | workbench | no |
| `fuel_cell` | 2 nitrogen + 1 plate -> 1, 90 t | workbench | no |
| `cure` | 2 refined + 1 bog_resin -> 1 cure, 90 t | workbench | no (Remission) |
| `craft_gear_*` | plates + refined -> a `GearItem` (vest 5 plate + 8 refined) | workbench, tech T2 | no |
| `make_ai_chip`, `essence_rounds`, `cook_meal`, `machine_parts` | see data | | no |
Old doc disagreement: economy_endgame.md says "refined/batch 3"; code has **6** since batch Y.

## Machines, belts, ports `[BUILT]` — `data/buildings.json`, `sim/logistics/`, `sim/automation/`
- Hand phase: `refinery` (2x2), `workbench`, `research_bench`, `stove`, `bed`, `turret`, `wall`/`door`.
- Automation (tech `drilling`/`conveyance`/`smelting`/`storage_ports`/`assembly`): `miner` on a node,
  `smelter`, `assembler`, `storage_in`/`storage_out` ports, `belt` (1 item/cell, 2 cells/s, drag-to-paint).
- Logistics 2: splitters basic/smart/priority + merger (`place_belt_node`, `set_splitter_filter`), techs
  `splitting`/`smart_logic`. Fair splitter->merger rotation (K4).
- AI chips (`data/chips.json`, tech `ai_chips`): bench 0.8 speed, processor 1.0 (unchipped 0.6), waste x1.3,
  threat x2, 1 refined/day upkeep, calibration every 3 d (job). Chips only in benches/smelters/assemblers.
- Taint cap (`refine_cap` rule) stops only waste-making recipes; clean crafts always run.
- Belts/machines take creature damage (`line_damage`), repair costs 1 plate (repair job, `repair_priority` rule).

## Power `[BUILT]` — `sim/power/`, `data/fuels.json`, `data/balance.json power`
Poles (range 6) form union-find nets; brownout = clamp(supply/demand, 0.2, 1); unpowered consumers run at
0.5. Generators burn conventional fuels, never essence (owner): `coal_generator`, `nitrogen_turbine`,
`nuclear_reactor` (meltdown, spent fuel contaminates), `solar_array` (12 power, clean, tech `clean_power`).
Open: solar 30 % of a smelter, brownout balance on one seed (K5).

## Where the economy stalls today (bot, 60 d)
Refined is plentiful (228-582 on good seeds) but goes to installments; **plates** gate repairs, audit tier
2 (40 plate + 10 parts), P1 and shuttle parts. See [99-backlog/balance-findings.md](../99-backlog/balance-findings.md).
Tools: `tools/factory_bot.gd` (real bot, public commands only), `tools/petition_pace.gd`, `tools/la_diag.gd`,
`tools/gear_budget.gd`.
