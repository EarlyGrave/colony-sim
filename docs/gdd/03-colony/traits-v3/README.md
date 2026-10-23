# Traits v3 — "The File" (integrated in F11, flag OFF)

Status: `[BUILT, flag OFF: traits_v3_enabled]` (F11: integrated - `TraitSystem` facade forwards to v3, `sim/colonists/trait_events.gd`, consumer hooks, badge row `view/panels/trait_sheet.gd`; deferred stats in `docs/agents/F11W1/f11-report.md`) — `data/traits_v3.json` (66 traits), `sim/colonists/trait_system_v3.gd`,
`tests/test_traits_v3.gd` (11 tests), icons `assets/sprites/trait_*.png` (`tools/gen_art.py`
`# region traits_v3`). Gated by `balance.traits_v3_enabled = false`: Defs does not load the file, Simulation
has no `traits_v3` member, goldens are byte-identical. Decided without owner, review.

| file | content |
|---|---|
| [README.md](README.md) | this: pillars, slots, rarity, conflicts, categories, how traits reach the phone |
| [acquisition.md](acquisition.md) | how traits are gained and lost: birth, the Charge, scars, essence ladder, block culture, prison aging; counters and events |
| [interactions.md](interactions.md) | trait needs (stress), bonds between inmates, auras, path leaning, synergy/anti-synergy recipes |
| [integration.md](integration.md) | stat → consumer registry, files to touch, wiring plan, migration from v2 |
| [table.md](table.md) / [table.json](table.json) | all 66 traits: icon, name, category, rarity, text, exact numbers, gained by, conflicts |

Sources reworked (not copied): RimWorld traits (two innate slots, weighted rarity, thought multipliers) ·
Dwarf Fortress personality needs (unmet trait needs become thoughts) · CK3 lifestyle/stress traits (acquired
from behaviour, lost by behaviour; ladders) · Darkest Dungeon quirks (scars from stress events, mutation
"afflictions" that replace lower rungs) · Battle Brothers backgrounds (the Charge: one history trait that
sets skills, debt and loyalties) · Against the Storm species (needs that only some inmates have; auras).
Our twist: every trait is a line in the Warden's file. The Charge is the crime, scars are prison time,
mutations are essence, social traits are block politics.

## Pillars (owner notes 2026-10-19 + bible)
1. **Never purely negative.** Every trait has a niche: Hollow ignores despair, Outcast ignores block shame,
   Shell-Shocked learns shooting fast. The weakest niche is "informant_weight -10" (never the snitch).
2. **Mining safe / refining dangerous.** Essence traits are only earned at the refinery, on tainted ground
   or from the waste pits. Clean colonies never see the mutation ladder.
3. **The file is public.** Traits are visible to the player at a glance (icon badge), never hidden stats.
   The one exception, `Charge: Sealed`, is a quest hook, not a hidden modifier.
4. **Deterministic.** Birth: fixed rng draw count (`innate_max + 4`). Acquisition: threshold counters, no
   rng. Bonds: one rng draw per candidate pair, iterated in id order.

## Slots (data `slots`)
| slot | cap | categories | how filled |
|---|---|---|---|
| innate | 2 (20 % none) | personality, body, `innate:true` extras (Clean Blood, Quiet One, Agitator) | birth draw |
| the Charge | exactly 1 | background | birth draw, always |
| social at birth | 0–1 (30 %) | social with `innate:true` | birth draw (counts toward acquired) |
| acquired | 3 total, mutation ≤ 2 | scar, mutation, social | events, ladders, bonds, quests |

Rarity weights common 30 / uncommon 12 / rare 5 / legendary 1 (legendary only via ladders and quests:
Hollow, Echo). Expected per newcomer: ~2.4 traits at birth, 4–5 after 100 days.

## Conflicts (`TraitSystemV3.conflict(held, id)` → "" or a reason)
`excludes` (checked both ways), `group` (temper, outlook, pace, build, blood, sleep: one per group), slot
caps (`slot:innate` / `slot:background` / `slot:mutation` / `slot:acquired`), `requires` and `replaces` on
acquire rules (ladders: a lower rung never returns once a higher rung is held). Bonds have their own
`excludes` (Quiet One never bonds, Outcast cannot be a Cellmate).

## Categories (66)
| category | n | colour | what it is | typical hooks |
|---|---|---|---|---|
| personality | 14 | amber | innate temperament | mood, breaks, work pace, leaning, informant pick |
| body | 10 | red | innate physique | carry, hp, healing, rest, alarm reaction, targeting |
| background | 13 | steel | **the Charge**: the crime that put them here | skills, debt size, suspicion, contraband, leaning |
| scar | 12 | crimson | prison time written on them | despair, standing, flee, xp |
| mutation | 8 | violet | essence exposure (ladder + side branches) | refining, armour, targeting, thoughts |
| social | 9 | teal | block politics, pairs, the Warden | auras, riots, standing, suspicion |

## Trait stress / needs (data `needs`)
Six traits carry a need the colony must feed (DF-style): Tunnel Rat wants a mining job every 2 days,
Curious wants active research, Dreamer wants a letter event, Creature of Habit wants the same job type,
Gallows Humor wants a living block mate, Hums wants to be near refined essence. Unmet for `days` → a thought
(`mood.json` ids listed in [interactions.md](interactions.md)) every day until met. Cheap: one daily check.

## How traits surface on the phone (touch-first, no hover)
- **Badge row** in the colonist section: 16 px icons ×2, category colour = the only legend needed. Tap an
  icon → bottom sheet with name, in-game line, effect summary (`TraitSystemV3.summary(c)`), "since day N".
- **Newcomer card** (arrival letter) shows the Charge first, then innate icons: the player reads the file
  before accepting the transfer.
- **Letters** on acquisition, Warden voice, ≤70 chars: "Inmate 4 is logged as Glowtouched. Rations unchanged."
  Losses are quieter ("Settled: withdrawn."). Ladder steps and Hollow get a real letter (one line of unease).
- **Squad/roles**: role affinity reads traits (Hulking → bulwark, Paranoid/Sharp Ears → scout).
- **Overlay**: inmates with `target_weight` > 0 glow faintly on the threat overlay (creatures prefer them).

## Open questions (owner)
1. Keep v2's 20 traits as aliases (mapping in [integration.md](integration.md)) or re-roll all dossiers on NG+?
2. Is `Charge: Wrongful` too strong a story claim for a random roll? Could be quest-only (Fresh Fish line).
3. Mutation cap 2: should Hollow be allowed to co-exist with Black Veins (full creature)? Currently yes.
