# Equipment module: slots, bases, rarity, durability

Status: `[BUILT]` (E2/E5/F3) — `sim/equipment/equipment_system.gd`, `gear_item.gd`, `stat_block.gd`,
`data/equipment.json`, `data/gear.json`; commands `give_gear` (tools), `equip`, `unequip`, `socket`.

## Slots (data-driven; code never names a slot)
head, hands, legs, torso_outer ("Armour"), torso_inner ("Underlay"), weapon. A new slot = one JSON entry +
a base with `"slot": "<id>"` (test adds a "back" slot via defs override). Physical and energy ratings sum
across all worn items.

## Bases (`data/gear.json`, affixless)
| base | slot | key numbers |
|---|---|---|
| prison_shiv | weapon (melee) | dmg 7, cd 8, range 1.5, skill melee — start gear |
| rifle | weapon (ranged) | dmg 12, cd 14, range 9, skill shooting — engineers' start gear |
| plasma_blade | weapon (melee, energy) | crit 8 % x1.6, accuracy +5 % |
| smg | weapon (ranged) | burst 3 / gap 1, magazine 24, reload 30, accuracy -5 % |
| kevlar_vest | torso_outer | armor phys 40 / energy 5, flat phys 2 |
| helmet, work_gloves, greaves, underlay | head / hands / legs / torso_inner | smaller armour + flat |
`weapons.json` keeps the legacy `combat` block (hit numbers) and `abilities`; `weapons` entries migrate 1:1.

## Rarity (`equipment.json rarity`)
common 0 affixes / uncommon 1 / rare 2 / epic 3 / legendary 4; colours per tier (icon frames in the UI);
upgrade sockets common 0 / uncommon 1 / rare 1 / epic 2 / legendary 2. Craft rarity weights
common 60 / uncommon 28 / rare 10 / epic 2 (ilvl 3); drops have their own weights (see crafting-loot.md).

## Durability (`equipment.json durability`)
max 100, -0.2 per hit taken, -0.1 per attack. **0 never destroys** (owner): the item's stat contribution is
multiplied down to `zero_stat_mult` 0.5 (linear from 50 %) and its trade value to 0.1. Repair job
`[PLANNED]` (future crafting/maintenance job; not built).

## GearItem model
`id, base, rarity, ilvl, affixes [[id, value]...], upgrades [ids], durability, quality, stats {}` — `stats`
summed once per change. Items on the ground are stacks `gear` x1 with `carry_quality = instance id`
(no schema change); `EquipmentSystem.instances` owns the objects; saves rebuild from commands + rng.
`state_hash` includes equipment only once any instance exists (goldens untouched).

## Where it still has no loop
Repair, trade value sink, dodge affix, enemy affixes, operating-branch effects on gear: not built.
`gear_owned` cond and `gear` quest verb exist (r4 lines, with [DATA] fallbacks).
