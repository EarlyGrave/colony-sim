# Story canon (summary) — full text in [docs/story/bible.md](../../story/bible.md)

Status: `[BUILT]` as the frame of every quest/letter; specific beats are tagged in
[04-society/revelation-arc.md](../04-society/revelation-arc.md) and [04-society/quests-storylines.md](../04-society/quests-storylines.md).

## Setting
- Far penal planet. Colonists are death-row lifers (grave crimes) who chose life labour over execution.
- The **Metropolis** (sector capital, antagonist faction) sets a quota of refined Essence. A transport
  shuttle collects on **Collection Day** = the 10-day installment deadlines of the debt ledger
  (`data/debt.json period_days 10`). In the UI "debt" is the quota ledger.
- Faces: the **Warden** (PA voice on site), the **Procurator** (shuttle voice, lands with the deal in Q14),
  the **Collector** (orbital hub sending drone shuttles; the Fight target), the **Ferry** (smugglers; the
  Escape buyer). Jailers = inspections/audits.

## Essence and Lull
Essence is concentrated planetary life, mined as ore (safe: still the planet's own) and refined for the
quota (dangerous: theft made visible). Waste is "forgetting": dead ground, silence, then madness.
Secret: refined Essence is the base of **Lull**, a euphoric that keeps the capital and the colonies from
protesting. It is made far away by hands nobody will miss. The quota is deliberately unpayable: a sentence
is "credited", never "served".

## Creatures
Not native predators. Stage 1: local fauna maddened (crawlers, spitters, burrowers, brutes). Stage 2:
mimics — the poison reshapes what it took, including earlier inmates and your own dead
(`Enemy.name_of_dead`, Q15 "Roll Call"). Final stage: the planet itself goes mad (Submit burns it out).
Refining *tempo* raises hostility: the scent clock is the lore made mechanical.

## Inmate archetypes = cell blocks (`data/blocks.json`)
Lifer (leans Submit), Clerk (Escape), Zealot (Fight), Informant (Metropolis), Fresh Fish (swings).
Traits are a separate innate layer ([03-colony/traits-scars.md](../03-colony/traits-scars.md)).

## The revelation in layers
Clues are flags: `clue_manifest` (Q6), `clue_survey_tag` (Q8), `clue_warden_quota` (Q10), `clue_buyer`
(S4b), `clue_our_dead` (Q15), `clue_receipt` (Q16). With 2 clues + day 30, Q14 "Three Forms": the Procurator
lands, the Clerk reads the small print, the colony picks a path. Before Q14 every path is the same game.

## Endings (one line each; mechanics in [07-endings-meta/](../07-endings-meta/README.md))
| path | tone | one-line |
|---|---|---|
| Submit | bad | deliver, take the deal, hold the madness siege, leave under new names; planet burned |
| Fight | good | refuse the shuttle, survive Metropolis raids, destroy the Collector; planet free for long |
| Escape | grey | sell covertly without raising suspicion, pay the Ferry, walk to a map point |
| Remission | proposed | keep the quota, cure the land with pylons; the only ending that rewards refining less |
Epilogue texts: `data/flavor.json epilogue.*` (built, shown on the win screen, with r4 echo lines).

## Meta frame
Next Sentence (NG+): "Balance carried forward." The Dossier (best colonist) returns; sentence 2/3/4+ letters;
fifth loop Warden quota screen is `[IDEA]` (not built). Q11/Q12 loop quests exist.
