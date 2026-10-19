# E2 report
- Added sim/equipment/{equipment_system,gear_item,stat_block}.gd, data/{equipment,gear,upgrades}.json, tests/test_equipment.gd (7 tests green).
- Commands on Simulation (region E2, all `_record`ed so replay/save works): give_gear, equip, unequip, socket. Defs gains equipment/gear/upgrades.
- state_hash part only when an instance exists (goldens untouched; quick suite 14/14 green incl. goldens/contract/phone).
- stat_block.gd is a STUB (KEYS, IDX, make(), sum_into(packed, dict, mult)); E1's version must replace it. Totals live in EquipmentSystem.totals[cid] (PackedFloat64Array in KEYS order); `# region E1` hook in `_resum` is where att/def get copied into CombatState.
- Durability: < 50% scales contribution linearly to zero_stat_mult (0.5 at 0); item never destroyed; set_durability resums only on band change.
- E3 hook: GearItem.resum_stats `# region E3` sums affixes [[stat_key, value]]; give_gear rolls no affixes yet.
- NOT done: start gear in colonist_system (would change goldens' hash/behaviour; weapon fallback to weapons.json stays). sim_contract.md was at the 250-line cap, so rows were merged into existing lines.
