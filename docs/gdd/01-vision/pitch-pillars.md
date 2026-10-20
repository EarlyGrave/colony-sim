# Pitch, pillars, core loop, tone

## Pitch
See the top-level [README](../README.md#pitch). One sentence: *lifers refine a planet to death for a
drug they will never see, and the planet answers in waves.*

## Pillars and how each is measured
| # | pillar | measured by | where |
|---|---|---|---|
| 1 | Mining safe, refining dangerous | `kx_pillar_table` gap >= 2 waves by d21 (baseline refines vs throttle vs mining-only) | `tools/kx_pillar_table.gd`, `data/balance.json pacing.pollution_interval` (dirty_mult 0.28, clean_mult 10) |
| 2 | Legible on a phone | 844x390 DPR3 overlap scan, world >= 55 % visible, buttons >= 64 px | `tests/test_phone_layout.gd`, `tools/web_smoke.py` |
| 3 | Deterministic, data-driven, bot-measured | goldens byte-identical unless intended; `factory_eval` before main | `tests/golden/*.json`, `tools/make_golden.gd`, `tools/factory_eval.sh` |
| 4 | Everything arrives as a form | Warden PA / letters / quest sheet; text <= 70 chars (tests) | `data/flavor.json`, `view/pa_banner.gd`, `view/feed_director.gd` |
| 5 | The colony is people | Blocks panel, Standing, traits, Informant have readable effects | `sim/society/`, `view/panels/blocks_panel.gd` |

Only `refine_essence` (and the dirty fuel cell) pollute (owner rule 2026-10-19). Any mechanic that makes
refining safer *on average* breaks pillar 1; mechanics may make the risk *legible and timed* instead.

## Core loop
- **Minute**: designate mining, place machines/belts, set bills, draft a squad, read a letter, answer a quest.
- **Day**: ore -> refinery (dirty) or smelter/assembler (clean) -> plates/parts/cells; pay the installment,
  research, build turrets; creature wave or audit patrol; needs, mood, despair; a storyteller beat.
- **Sentence** (run, 40-90 days): pickups + inspections -> clues -> the truth (Q14) -> path -> point of no
  return -> ending -> legacy + Next Sentence.
- Early game is one tutorialised loop (Warden's Orientation, 12 steps) identical on every path.

## Tone rules (bible)
- Bureaucratic dark comedy over real dread. Terse, deadpan, never cute about death.
- The Warden is a PA that has read your file and is disappointed in the file. It never lies; it omits.
- One line of genuine unease per quest, then back to paperwork.
- All in-game text English (owner rule 2026-10-18); names in `data/*.json`; <= 70 chars per line.

## Platform
Godot 4.7.2, GDScript only, GL Compatibility, single-threaded web export on GitHub Pages (deploys from
`main`). Phone-first touch UI; pseudo-3D view (flat layers on a tilted ground plane, 16 px/cell).
Details: [10-tech/architecture.md](../10-tech/architecture.md).

## Out of scope (for now)
Factions beyond the Metropolis, trade with NPC factions, real art, sound, children/relationships.
Keep architecture open (new `sim/<dir>` + bus signals) but do not build them.
