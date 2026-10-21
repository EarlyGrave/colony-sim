# Storyteller events v2 ("Storyteller II")

Code: `sim/storyteller/director.gd` (tension, rolls), instances via `QuestLog` (one-beat quests).
Data: `data/events_v2.json`. Flag `balance.director_enabled` (default false). All `[DESIGNED]`.

## 1. Today vs v2
Today: `storyteller.gd` rolls twice a day with chance 0.25 over `events.json` (8 events, one broken link at a
time), a second stream for `events_prison.json` chains (6 events + steps), `crises.json`, raid complications.
It has no memory of how hard the last days were beyond `colony_is_whole()` and `quiet_before_wave_ticks`.
v2 keeps all of that and adds: a **tension meter**, **categories with cooldowns**, **conditions that read
the world** (traits, Charges, blocks, path, pollution, stock), **choice cards with a price and a timer**,
and **memory** (flags that later events read). Reworked from: RimWorld (storyteller picks incident
categories by population/wealth and keeps threat points separate), Against the Storm (a two-option card
where investigation always costs something, timers on dangerous ones), FTL (text card + 2-3 options, a
roll hidden behind some), Frostpunk (the ledger of what you chose).

## 2. Event structure (`data/events_v2.json`)
```
"ev_rust_wind": {
  "cat": "weather", "kind": "choice"|"notice"|"chain",
  "weight": 3, "cooldown_days": 14, "cat_cooldown_days": 2, "min_day": 4, "max_day": 0,
  "max_per_game": 4,
  "requires": {conds...},          // AND dict (quest-trigger language + new conds)
  "boost": [{"cond": {"has_trait": "t_tar_lungs"}, "mult": 2.0}],
  "block_if": {...},                // veto conds (e.g. a wave warning)
  "harm": 0..3,                     // 0 boon/neutral, 1 nuisance, 2 painful, 3 crisis
  "tension": +6,                    // delta applied when it fires (negative = relief)
  "pick": {"as": "who", "by": "trait:t_tar_lungs"},   // optional colonist pick
  "text": [...lines <= 70...], "expire_days": 2, "default": "dec",
  "options": {"a": {"label","hint","requires","effects":[...]}, ...},
  "then": {"event": "ev_x", "delay_days": 2, "p": 0.7}   // chain
}
```
Kinds: **notice** = text + `effects`, no card (letter log, 1 line toast); **choice** = card with 2-3
options; **chain** = a notice/choice whose `then` schedules a follow-up (the follow-up may be a template of
System A). `harm >= 2` events obey the *harm rule* (section 4). Effects use the shorthand of
[generator.md](generator.md) section 8.

## 3. Categories (9) and what each is for
| cat | id prefix | n | role | typical `harm` | reads |
|---|---|---|---|---|---|
| camp life | `camp` | 5 | texture, small choices: food, sleep, a game of cards | 0-1 | moods, meals, beds |
| weather / planet | `wx` | 5 | dust, storms, tremors, long nights; brief timed modifiers | 1-2 | pollution, day, power |
| essence & mutation | `ess` | 6 | humming batches, glow, waste pits; trait ladder food | 1-2 | refined, `mutation`, Glowtouched |
| society / blocks | `soc` | 6 | gossip, favours, quarrels; moves Standing | 0-2 | block Standing, bonds |
| Warden & audits | `war` | 5 | paperwork incidents, PA glitches, forms with a price | 0-2 | debt, installments, suspicion |
| creatures (non-wave) | `crt` | 5 | sign, strays, a lone mimic at the fence, scent | 1-2 | scent, dormant, pollution |
| metro | `met` | 4 | overflights, wrecks, ransom notes, tolls | 1-2 | defiance, path, raids survived |
| gear / loot | `loot` | 4 | crates, salvage, a confiscation, a trade | 0-1 | gear owned, parts |
| pasts (Charges) | `past` | 4+ | an inmate's crime comes calling; scars, deeds, marks | 0-2 | `t_charge_*`, traits |
(44 events total in the pool; counts in the pool files.) **Category cooldown** keeps variety: after a
category fires its weight x0.2 for `cat_cooldown_days` (2), and the last 3 events' categories are
remembered (x0.5 each repeat).

## 4. Tension budget (the model)
Meter `T` in [0,100], integer arithmetic per day tick + increments on bus signals.
| source | delta |
|---|---|
| `wave_started` index i | +min(35, 12 + 1.5 i) |
| colonist died (any cause) | +10 each (cap +20 per day) |
| metro raid started | +20 |
| installment missed (once per period) | +8 |
| harmful event fired | + its `tension` (5 / 9 / 14 for harm 1/2/3) |
| crisis posted (`crises.json`) | +10 |
| relief event fired | its negative `tension` (-4..-12) |
| each quiet day (no wave, nobody broken, nobody sick) | -8 |
| each ordinary day | -4 |
Bands and what they do to rolls:
| band | T | harm events | boons / relief | errand offers | notices |
|---|---|---|---|---|---|
| CALM | < 20 | x1.6 | x0.6 | x1.2 | x1.0 |
| STEADY | 20-50 | x1.0 | x1.0 | x1.0 | x1.0 |
| STRAINED | 50-75 | x0.3 | x1.8 | x0.5 | x1.0 |
| CRITICAL | > 75 | x0 | x2.5 | x0 | x0.5 |
**Roll**: 2 checks/day (the storyteller's `checks_per_day`). Chance per check `p = 0.35`, x1.4 in CALM,
x0.5 while a card is pending. Fixed 3 `_drng` draws per check (chance, pick, spare). Max 2 director cards
per day and `card_gap_min` 0.75 d between cards.
**Hard vetoes** (no weight can override): no `harm >= 1` event while `wave_active`, `wave_pending()`, inside
`quiet_before_wave_ticks`, while any building is broken or any inmate sick/downed (`colony_is_whole()`),
while another `harm >= 2` event is active, or in the first 2 days after a wave that killed someone
(`calm_after_hit_days`). Boons are exempt.
**Waves stay the pillar**: the director never schedules, delays or cancels waves. It reads
`threats.next_wave_tick`: if a wave is due within 1.5 days it fills the gap with boons/notices only, so
the player's prep window is not eaten. Events may add `wave_mult` *mods* (existing) with a visible price.
**Expected volume** (60 days, standard preset, bot-like play): ~28 director cards (events) + ~8 errand
offers + ~12 waves + ~14 main-quest beats => about one card per 1.3 days on the phone, never two at once.

## 5. Referencing traits, Charges, passives (the "pasts" layer)
- **Pick selectors** (`pick {as, by}`): `trait:t_x` (first by id), `charge:t_charge_x`, `lowest_mood`,
  `highest_skill:mining`, `block:lifer`, `oldest` (most `day_served`), `random` (fixed 1 draw from
  `_drng`, consumed even when unused). No eligible inmate = event vetoed.
- **Boost** by traits: weight x2 if *any* living inmate has the trait (`has_trait`): a Curious inmate makes
  the "strange signal" event likelier; Tar Lungs makes dust storms nastier (a distinct option).
- **Write-back**: `trait_event who name` (feeds `TraitSystemV3.event` counters such as `rescued`,
  `calm_day`, `reported`), `tr who id` (acquired trait), `trdel who id` (lift a scar), `deed who d_id`
  (passives v2 deed), `mark who n` (marks). Rules: an event grants at most one permanent trait; scars
  from events are always *opt-in via the player's choice* or the cost of declining, quoted on the button.
- **Charge events** (`past`): Arson, Fraud, Smuggling, Sedition, Desertion, Cult, Poaching, Essence Theft,
  Debt, Murder, Mutiny, Wrongful, Sealed — one event per Charge family exists in the pool (some share).
  Each fires at most once per inmate (flag `past.<id>.<charge>`).
- **Passives**: events grant deeds that exist in `passives_v2.json deeds` (e.g. `d_rescuer`, `d_got_up`,
  `d_thirty_quiet`) or marks (1-2); never a keystone. Hooks for new deeds are listed in integration.

## 6. Memory and chains
Flags set by options (`ev.<id>.<option>`) persist in `QuestLog.flags`; later events read them via `flag` /
`not_flag` requires. Examples: `ev.hum_batch.record` makes the Echo giver of SQ-line "Seat Nine" appear;
`ev.warden_form.sign` makes later audits slower (a small `audit_parts_mult 0.95`). Chains: `then` events
fire after `delay_days` with probability `p`, bypass the card gap but not the harm vetoes (retried next
day for 3 days, then dropped).

## 7. Cooldowns and limits (defaults)
Per event `cooldown_days` 6-30 (boons 12+, harm 2: 18+); `max_per_game` 1-4 for anything memorable;
global `max_harm_per_5_days` 2; global `max_choice_cards_per_5_days` 4. Same colonist is picked at most once
per 6 days (`pick_cooldown`). Seasons: none (no calendar); weather events use `day % 10` only through
cooldowns, not a calendar.

## 8. Sanity and tests (see integration.md)
Report tool `tools/director_report.gd` prints per seed: cards per day, harm per band, T curve, category
histogram, events within a wave warning (must be 0 for harm >= 1), repeated template within cooldown (0).
Acceptance: over 10 seeds x 60 d, harm events within 1.5 d before a wave = 0; the median T never > 60;
`alive aggregate` with the flag on not lower than off by more than 2 (pillar guard, same style as the
contraband check).
