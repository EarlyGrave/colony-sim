# Gear sources: start gear, crafting, loot, rewards

| source | status | where | numbers |
|---|---|---|---|
| Start gear | `[BUILT]` (F3a) | `colonist_system.gd` region E2 | every inmate a common `prison_shiv` GearItem; engineers a `rifle`; goldens regenerated once |
| Craft gear | `[BUILT]` (E5/F3b) | recipes `craft_gear_rifle/vest/helmet/gloves/greaves`, workbench, tech tier 2 | vest = 5 plate + 8 refined (~2 installments); rarity by `sources.craft_rarity_weights`, ilvl 3, quality tier from crafting skill |
| Creature loot | `[BUILT]` (F2c) | `enemies.json loot`, `threat_system.gd` region F2, `equipment.drop_at` | child rng; rarity weight x (1 + 3 x pollution_frac) (tainted gear = the prison-planet twist); ilvl by day (`gear.json _ilvl_by_day`); no loot before day 6 (`_loot_min_day`, keeps goldens) |
| Drone loot | `[BUILT]` | `equipment.json sources.drops.metropolis` | 12 % per drone, bases rifle/smg/helmet/vest/gloves/greaves, legendary 1 %, ilvl 6 |
| Wave reward | `[BUILT]` (F3a) | `gear.json _wave_reward` | 35 % chance of an armour piece after a repelled wave (pity source for seeds with few kills) |
| Fixation masterwork | `[BUILT, flag OFF: fixation_enabled]` | `sim/fixation/`, `data/fixation.json` | legendary ilvl 10, named after the inmate |
| r4 quest `gear` verb | `[BUILT]` | `quest_log.gd` region W4 | e.g. strip the drone -> uncommon plasma_blade/smg |
| Repair | `[PLANNED]` | — | durability never destroys, so repair is a future maintenance job |
| Trade / sell gear | `[IDEA]` | — | `value` exists on bases; no buyer |

## Gear economy numbers (`tools/gear_budget.gd`, F3b, 60 d)
A vest per inmate costs 5-9 % of refined (24 % on poor seeds) and lowers debt paid by 15-30 %; **plates are
the binding constraint** (same wall as the petition). Bot equips best gear by default (`equip` knob):
alive 6/10 both ON and OFF at the time; after the FX5 bot fix gear_equipped 2-17 per seed, alive 7/10.
Loot eval (`tools/gear_loot_eval.gd`): >= 3 drops on 6/10 seeds (seeds 1/6/8 see zero waves).

## Design rule
Gear never makes refining cleaner; it changes how many inmates come back from a wave. Costs are plates +
refined so gear competes with the quota and the petition (one currency, many sinks — see 02-economy).
