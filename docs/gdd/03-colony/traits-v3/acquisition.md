# Traits v3 — acquisition and loss

Everything below is data (`data/traits_v3.json` `acquire`, `lose`, `ladders`, `bonds`) read by
`TraitSystemV3.event(c, name)`. The consumer (integration batch) only emits named events; the module keeps
counters in `c.bio.trait_counters` and applies thresholds. No rng anywhere in acquisition.

## 1. Birth (`apply_birth(c, rng, {block})`)
Fixed draw order, `innate_max + 4` = 6 rng draws per newcomer:
1. `randf` < 20 % → no innate traits (the draws still happen, results ignored).
2. two innate draws, weighted by rarity, from personality + body + `innate:true` extras, filtered by
   `conflict()` against what is already chosen and by `block_only` (none yet in v3; kept for data).
3. one Charge draw (background, always one; rare Charges 5/118 ≈ 4 %).
4. `randf` < 30 % → one social draw (Quiet One common, Agitator uncommon).
Then: skill bonuses applied (clamped 0..10), `bio.work_speed` cache updated, `max_hp` adjusted (Wiry -15,
Dead Nerves -10, Lean Years -5), `trait_log` gets `{day, id, op:"add", src:"birth"}`.

## 2. The Charge (background) — why one is mandatory
The bible says every inmate is death-row. The Charge is the sentence line of the file: it sets the debt
multiplier (`debt_total`: Murder +20 %, Debt +10 %), opening skills, the Warden's attention
(`suspicion_gain`), what the inmate is good at smuggling, and which ending they lean to. It never changes,
except `Charge: Sealed`, which a quest can replace (`remove` + `add` with `source:"quest"`) once the file is
opened — the only time a background slot is re-filled.

## 3. Scars (prison time) — events the consumer must emit
| event | emitted by (integration) | gives | threshold |
|---|---|---|---|
| `rescued` | bus `colonist_rescued` | Hardened | 1 |
| `despair_day` / `despair_relief` | DebtSystem daily (despair ≥ 80 / < 80) | Resigned | 5 days, reset on relief |
| `calm_day` / `break` | day without a break / bus `mood_break_started` | Settled (lost on break) | 30 |
| `downed_in_wave` | bus `colonist_downed` while a wave is active | Shell-Shocked | 2 |
| `wave_unscathed` | bus `wave_ended` for colonists not downed in it | removes Shell-Shocked | 3 |
| `heavy_injury` | bus `injury_added` with severity ≥ 20 | Marked | 3 |
| `docked` / `period_paid` | DebtSystem dock / full period paid | Docked (lost when paid) | 1 |
| `block_wiped` | BlockSystem: last living member of the original block | Last One | 1 |
| `starving_day` / `ate` | bus `colonist_starving` daily / `colonist_ate` | Lean Years | 3, reset on eating |
| `reported` / `informant_gone` | InformantMod report hits this inmate / informant leaves | Reported | 1 |
| `day_served` | bus `day_started` for every living inmate | Cell Rot (60) → Old Timer (120, replaces) | ladder |
| `escape_stopped` | bus `escape_stopped` | Runner | 1 |

## 4. Essence ladder (mutation) — the pillar
Refining is the only source. The MutationSystem already rolls `toxic_fallout` on tainted ground
(`mutation_risk` multiplies it); each illness emits `exposure_illness`:
- 1 → **Glowtouched** (refines faster, creatures notice, risk +20 %)
- 3 → **Second Skin** (replaces; armour +1, hunger, risk +30 %, block mates uneasy)
- 6 → **Hollow** (replaces; legendary: no thoughts, despair frozen, armour +2, creatures ignore, no petition)
Side branches, not on the ladder: **Hums** (40 refining batches operated), **Black Veins** (10 creature kills
on tainted ground; immune to further illness — the body gave up fighting it), **Waste Kin** (60 scrubbed
cells), **Echo** (met a mimic while Glowtouched; carries a revelation clue flag `clue_bearer`).
`Clean Blood` is the innate counterpart (rare, rolled at birth): -50 % illness chance, slower refining.
Mutation cap 2 of the 3 acquired slots; a lower rung never returns (`_superseded`).

## 5. Block culture (social) — block standing as a clock
| event | emitted by | gives | threshold |
|---|---|---|---|
| `high_standing_day` / `low_standing_day` | BlockSystem daily, standing ≥ 70 / ≤ 30 | Block Boss (10 days high; lost after 5 low) / Outcast (10 low; lost after 5 high) | reset by the opposite day |
| `made_informant` | BlockSystem informant pick | Warden's Ear | 1 |
| `riot` | bus `riot_started` by this inmate | Agitator | 2 |
| `skill_seven` | bus `skill_leveled` level 7 | Mentor | 1 |
| `calmed_break` | MoodSystem: a block mate's break roll failed thanks to this inmate's `aura_break` | Peacemaker | 3 |
Block Boss and Outcast are mutually exclusive and self-correcting: one rises as standing rises.

## 6. Pairs (bonds) — `try_bond(a, b, id, days, rng)`
Cellmate: 20 days in the same block, 15 %/day; both get the trait and `bio.trait_links[t_cellmate] = other`.
Rival: 10 days on the same job type, 10 %/day. One rng draw per candidate pair per day; the consumer walks
pairs in ascending id order. Partner death/transfer → `break_bond(c, id)`: trait removed, counter
`lost_t_cellmate` kept for a future "grief" thought and for the quest verb `trait`.

## 7. Aging in prison
`day_served` is the only clock: Cell Rot at 60 days (slower learning, calmer), Old Timer at 120 (plus
standing, petition weight, slower walk). With `acquired_max` 3 the ladder competes with scars, which is
intended: a long sentence fills the file.

## 8. Quests
Quest verb `trait {who, id}` (QuestLog) maps to `add(c, id, "quest")` / `remove`. Story writer can grant any
trait, including legendary ones, bypassing nothing but the slot caps.

## 9. Counters and log
`bio.trait_counters` holds every event count (`rescued`, `day_served`, `need_t_curious`, `lost_t_cellmate`);
`bio.trait_log` is the audit trail for the dossier panel and NG+ (`start_opts.gd` re-applies ids).
