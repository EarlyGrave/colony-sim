# Affixes and sockets

Status: `[BUILT]` (E3) — `sim/equipment/affix_roller.gd`, `data/affixes.json`, `data/upgrades.json`,
report `tools/affix_report.gd` (1000 rolls per rarity: group split, duplicates), `tests/test_affixes.gd`.

## 14 affixes in 3 groups (affix id == StatBlock stat key)
| group | affixes |
|---|---|
| offense | dmg_pct, crit_chance, accuracy, attack_speed, pen_pct_phys, pen_pct_energy |
| defense | armor_phys, armor_energy, flat_phys, flat_energy, max_hp |
| utility | move_speed, ammo_eff, durability_max |
Each: name pattern (prefix "Plated %s" / suffix "%s of Ruin"), `tiers` of [min, max] by ilvl bracket
(`tier_by_ilvl` [0, 5, 10]), `tags_any` (weapon / armor) so a vest never rolls `dmg_pct`.
Rules: `max_prefix` 2, `max_suffix` 2, `max_per_group` offense 2 / defense 2 / utility 1, one affix id per
item. Reserved, not implemented: `dodge` (flat p-hit subtraction, cap 0.25).

## Roller
`AffixRoller.roll(base, rarity, ilvl, rng)`: n = rarity.affixes; candidates = affixes whose tags match and
whose group/pos caps are not full, iterated in sorted key order, weighted pick with a child RNG seeded from
`sim.rng.randi()`; tier = highest <= ilvl bracket; value uniform in the tier range. Same seed -> same item.
Report: legendary offense/defense split 40-60 % over 1000 rolls.

## Upgrade sockets (`data/upgrades.json`)
`kevlar_plate` {flat_phys +3} (armour), `ap_rounds` {pen_pct_phys +0.25} (weapon). Same stat keys, same
summation; `socket(item_id, upgrade_id)` checks free sockets and `tags_any`, then pays the
upgrade `cost` from stock `[BUILT]` (F9W1, `upgrades.json`: kevlar_plate 2 plate; ap_rounds 1 plate + 2
essence_rounds); refused with nothing consumed when short; buttons show the cost.

## Performance rule
Affixes are never iterated per hit: pre-summed into `GearItem.stats`, then into the unit's packed
`att`/`def` (see [05-threats-combat/combat-math.md](../05-threats-combat/combat-math.md)).

## Ideas
Tainted gear (loot rarity already scales with pollution): stronger offence affixes + a contamination puff
on crit `[IDEA]`; enemy affixes `[IDEA]`; branch-gated affix tiers `[IDEA]`.
