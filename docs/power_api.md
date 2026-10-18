# Power API (L3) for L4 (view) and L5 (data)

Code: `sim/power/power_system.gd` (`sim.power`), `sim/power/power_net.gd` (union-find). Tick: `power.tick()` right before `buildings.tick_machines()`.

## Data it reads (all optional except where noted)
- `buildings.json`: consumer `power_use`; generator `power_gen` + `fuel` (`{item, burn_ticks, waste_per_burn}` | item id string | `{items:[...]}` | `null` = passive/solar), `input_capacity`, `output_capacity` (waste/spent land in the output buffer, overflow on the ground), optional `wear_per_burn`, optional `meltdown {fuse_ticks, condition_below, radius, damage, contamination}`; pole `power_range` (cells). Machines: extractor/processor consumers are throttled; `research_bench` draws power only while a tech is active (no throttling yet).
- `fuels.json` (`defs.fuels`, loaded if the file exists; wrapper key `fuels` tolerated), per fuel item, every field optional: `burn_ticks` (else def.fuel.burn_ticks, else derived from `energy` / `power_gen` x 10 ticks/s), `waste` | `waste_per_burn` (float, remainder carried), `contamination` (added to the planet level per burn), `spent_item` + `spent_per_burn` (default 1).
- `balance.json` `power` (optional): `min_factor` 0.2, `unpowered_factor` 0.5, `chip_use` 10 (extra demand per installed AI chip), `bucket` 0.05.
- `threat.json` `state_mod`: `powered_gen` (1.0, flag set while a generator burns for demand) and `unfuelled` (0.25, generator with no fuel); a def's `threat_mods` overrides both.

## Rules
Enforcement is OFF (`power.enabled == false`, factor 1.0, nothing in `state_hash`) until the first pole or generator exists; then it latches on. Consumer demand counts only while working (processor: batch running or inputs buffered with output room; extractor: output not full). Generators burn one fuel unit per `burn_ticks` only while their network has demand. Waste is the `waste` item (ledger source `power_waste`), spent fuel ledger source `power_spent`, fuel consumed sink `power_fuel`, meltdown event `power:meltdown`. Overheat: a generator with `meltdown` that is broken or at condition <= `condition_below` while fuelled heats 1/tick (cools 2/tick otherwise); at `fuse_ticks` it is destroyed, adds `contamination`, and damages buildings within `radius`.

## Read API (no per-frame cost beyond arrays)
- `enabled: bool`, `version: int` (bumps on every topology rebuild; redraw wires only then), `nets: Array[Dictionary]` static `{id, poles: [building ids], gens: [Building], users: [Building]}`, `links: PackedInt32Array` flat `[a, b, a, b...]` building-id pairs (pole-pole and pole-nearest-building).
- `net_info(net_id) -> {id, poles, gens, users, supply, demand, factor}`; `worst_net()` same for the lowest factor (HUD chip "PWR supply/demand"); `net_id_of(b)` (-1 = consumer with no pole, 0.5 speed); `factor_for(b)`.
- Per generator: `supply_of(b)`, `fuel_left(b)`, `burning(b)`, `fuel_items(b)`, `waste_per_1000(b)`; `Building.heat` (overheat counter), `Building.burn_left`.
- Bus: `power_changed(net_id)` (factor moved to another 0.05 bucket, never per tick), `power_meltdown(building_id)`.
- Generators accept only their fuel through `Building.input_space` (hand-hauling and belt ports work unchanged).
