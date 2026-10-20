# Combat math (one hit roll, one damage function)

Status: `[BUILT]` — `sim/combat/combat_system.gd` (`resolve_hit`), `combat_state.gd` (cached `att`/`def`
packed arrays), `sim/equipment/stat_block.gd` (KEYS/IDX), `sim/threats/enemy.gd` (att/def from def),
`sim/health/health_system.gd` (apply damage, role/perk mults from cached def). Owner notes: LoL-style
armour, flat before percent, min 1, % penetration, no true damage, energy as a second rating.

## Hit roll (inmates only; enemies auto-hit and are dodged by position)
`p_hit = clamp(hit_base 0.5 + hit_per_skill 0.08 x level + acc_weapon + acc_affix - range_penalty 0.03 x
max(0, dist - 1), 0.05, 0.95) x manipulation`; `aimed_shot` perk short-circuits. **No evasion stat**
(decision, owner question 6); `dodge` is a reserved utility affix id, not implemented.

## Damage pipeline (`resolve_hit(att, def, kind)`, ~15 ops, no loops, 1 `randf` for crit)
```
raw        = dmg_base * crit_mult (if rng < crit_chance; default 1.5)
armor      = max(0, def.armor[kind] * (1 - att.pen_pct[kind]))      # penetration = % of rating ignored
after_flat = max(0, raw - max(0, def.flat[kind] - att.flat_pen[kind]))  # flat plate BEFORE the curve
dealt      = max(1, after_flat * 100 / (100 + armor))               # 100 -> -50 %, 200 -> -66 %
```
kind = "phys" | "energy" (weapon `damage_kind`); health injury kind (cut, bullet, burn...) stays separate.
Table test: raw 20 / armour 100 -> 10; armour 200 -> 6.67; flat 3 then armour 100 -> 8.5; pen 0.5 vs 100 -> 13.3.
With all-zero armour the result equals the pre-equipment numbers (goldens unchanged by the migration).

## Stat blocks (phone budget: 200+ fully equipped units in one raid)
- `GearItem.stats` summed once at creation / socket / durability band (<= 6 affixes + 2 upgrades).
- `Colonist.combat.att/def: PackedFloat64Array` re-summed only on equip/unequip/socket/durability band/
  skill level/perk/trait change (bus events), never per hit. Perk mods `hit_chance`, `melee_damage`,
  `attack_speed`, `damage_taken`, squad `role_mult`, trait `hit`/`armor_flat` fold into the resum.
- Enemies fill `def` at spawn from `armor`/`flat` (+variant). No per-enemy affixes.
- Forbidden in the hit path: string Dictionary lookups, iterating affixes, `perks.mod()`.
- Bench (`tools/equip_bench.gd`, `tests/test_equip_perf.gd`, `tests/perf_budget.json combat`): 250 map,
  224 inmates x 6 legendary items vs 300 enemies -> combat bucket **0.66 ms/tick** desktop (~6-7 ms web
  estimate); the big-battle cost is jobs + movement, not gear.

## Ranged parameters `[BUILT]` (E4)
Burst `{shots, gap_ticks}`, `magazine`, `reload_ticks` (SMG 3-shot burst, 24 rounds, 30-tick reload); melee
`crit_chance`/`crit_mult`; `accuracy` per base. Rifles draw `essence_rounds` from the inmate's pouch
(`data/ammo.json pouch`), turrets from their buffer (D23).

## Squad roles in the math
Bulwark `dmg_taken_mult` 0.4 (lasts ~2.2x an unsquadded inmate), Lancer volley x2.5 damage (TTK on a brute
40 % of a rifle inmate), numbers from `tools/combat_model.gd` (analytic DPS/TTK, armour columns from
`gear.json`: a vest gives x1.8-2.1 survival vs crawler/burrower/mimic) and guarded by
`tests/test_combat_model.gd`.

## Model/tools
`tools/combat_model.gd` (TTK tables, 2b armour), `tools/combat_report.gd`, `tools/affix_report.gd`.
Rule (CLAUDE.md 9): balance from the model table, not by eye.
