# Side quests and random events (design, NOT built)

Status: `[DESIGNED]` — docs only, owner request 2026-10-21. Everything is behind new flag
`balance.director_enabled = false` (goldens untouched). Decided without owner, review.

| file | content |
|---|---|
| this README | the two systems on one page each, shared budget, phone UX, sources |
| [generator.md](generator.md) | side-quest generator: templates, pools, scaling, rng, chains, rewards, mapping onto QuestLog |
| [events.md](events.md) | storyteller events v2: categories, structure, tension budget, trait/passive hooks |
| [pool_quests.md](pool_quests.md), [pool_quests_b.md](pool_quests_b.md) | 32 side-quest templates (SQ01-SQ32) |
| [pool_events.md](pool_events.md), [pool_events_b.md](pool_events_b.md) | 44 events (EV01-EV44) |
| [integration.md](integration.md) | 4-worker batch, new verbs/conds, data files, tests, bot knob, risks |

Sources (checked live 2026-10-21, reworked not copied): RimWorld storytellers (threat points from wealth,
quests scaled by the threat-scale setting, a violent-quests toggle), Against the Storm glade events (a
two-option card, every investigation paired with a cost, "working effects" you must survive, timers on the
dangerous ones), plus from memory: FTL (one text card, 2-3 choices, a hidden roll behind some), Darkest
Dungeon (curios: a choice with a visible price), Frostpunk (laws and crises with a ledger of consequences),
Banner Saga (caravan events whose price is carried forward), Stellaris (anomalies: a timed survey, then a
branching outcome). Our twist: the offerer is always somebody in the file (a block, the Warden, a dead
inmate), every offer quotes its price in the Warden's currency, and nothing pays without contaminating,
indebting or exposing somebody.

## System A — Side quests (the "errands")
Goal: a trickle of short, optional, *personal* jobs between the curated main quests (Q1-Q16, S1-S6, r4).
Main quests are authored and one-off; errands are generated from a pool, repeat with different numbers and
givers, and make the blocks, the Informant and the Warden feel like people who want things.
- **Pacing**: first offer d6; one new offer every 3-7 days (avg 5); at most 2 open at once; never while a
  main-quest card is pending, never inside a wave warning window; <= 30 offers per 100 days.
  Errand length 2-8 days; offer expires in 1-3 days (default = decline with a small cost, quoted).
- **Shape**: offer card (giver, one-line ask, 2-3 options with price) -> work happens in normal play (stock,
  build, survive, protect...) -> checked at the next dawn "roll call" -> reward or failure letter.
- **Never**: grants revelation clues, changes the path, or blocks the main line. Rewards are *useful but
  taxed* (items, a small debt cut, Standing, marks, a trait or a scar), failures are *felt but not fatal*.
- Chains: some errands carry a `chain` to a sequel (2-3 steps = a mini story line, e.g. "The Courier").

## System B — Random events v2 ("Storyteller II")
Goal: make the planet and the prison feel alive between waves: weather, essence oddities, block gossip,
Warden paperwork, creature sign, drone overflights, loot, and the *pasts* of individual inmates.
- Events are one-beat quests (same engine, same card). 44 authored events in 9 categories, 3 kinds:
  **notice** (text + effects, goes to the log), **choice** (card with 2-3 options and a timer), **chain**
  (starts a follow-up in 1-3 days).
- **Tension budget**: a director keeps a 0-100 `tension` meter fed by waves, raids, deaths and harmful
  events and drained by quiet days. It decides *what kind* of event may roll: harmful in calm, relief and
  boons when strained, nothing harmful ever inside a wave window or while a link is already broken.
- Pasts: events can pick an inmate by trait/Charge ("Arson: the foundry smells of smoke") and write back
  scars, deeds and marks. This is where traits v3 and passives v2 get *stories*.

## How they share the storyteller budget
One `Director` (`sim/storyteller/director.gd`) owns both. It never schedules waves or metro raids (those
stay on the pollution / sentence / defiance clocks) — it only *reads* them and spends around them:
1. **Waves and raids spend tension** first (+12..+35 and +20). Event and errand volume is a function of what
   is left: calm day -> ~1 card per day; strained -> relief only; critical -> silence.
2. **Harm rule** (kept from today): no harmful event within `quiet_before_wave_ticks`, in a wave warning,
   during a wave, or while any machine/inmate is already broken ("one broken link at a time", D15).
3. **One card at a time** across main quests, errands, events, crises, choices (single pending queue).
4. Classic events (`events.json`) and prison chain (`events_prison.json`) stay; with the flag on their
   chance is halved (`director_classic_mult` 0.5) so card count does not double.

## Phone UX (844x390, touch)
- **One card**: title line (giver icon + name), <= 3 text lines of <= 70 chars, 2-3 buttons >= 64 px.
- **Cost quoted on the button hint**: "-8 refined. Clerks +8." (existing `hint` field). Accept buttons
  that need stock grey out when the stock is missing (existing `requires`).
- **Expiry timer** under the text: "Expires in 2 d - then: Decline". Unanswered = the default option.
- Notices never block: they land in the letter log with a badge; at most one toast at a time.
- Open errands live in a 2-row strip in the quest sheet: giver, goal "4/6 refined", "due in 3 d".
- No tension meter shown to the player (it is the director's secret); a debug line in the dev HUD only.
