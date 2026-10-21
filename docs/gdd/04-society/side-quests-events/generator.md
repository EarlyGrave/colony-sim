# Side-quest generator

Code: `sim/quests/quest_generator.gd` (builds an instance from a template), `sim/storyteller/director.gd`
(chooses when and which). Data: `data/side_quests.json`. All `[DESIGNED]`.

## 1. Idea in one paragraph
A **template** is an authored errand with typed slots: *giver x goal x twist x reward x failure*. The
generator picks a template by weight, rolls the slot parameters with a **child rng**, writes the concrete
result into an **instance** (an ordinary quest dict: beats/options/effects) and starts it in `QuestLog`.
The engine needs no new "quest type": an errand is a 3-beat quest — `offer` -> `check` (gated by the F6
`wait`) -> done. Instances are rebuilt from `(template, params)` so state stays tiny and replayable.

## 2. Mapping onto the existing engine
| errand part | engine feature (exists) | new bit |
|---|---|---|
| offer card | beat with `options` -> `offer()` -> `quest_choice_posted` | `expire_days` + `default` on the beat |
| price on the button | option `requires` (greys out) + `hint` text | none |
| accept effects | option `effects` (`items -n`, `pick`, `snap`...) + `then: check` | verbs `pick`, `snap`, `spawn_colonist as` |
| waiting for the goal | beat `wait` (AND dict / OR array), `wait_max_days` (F6) | conds `stored`, `built`, `since`, `ref_dead`... |
| win / fail branching | none | verb `if {cond, then[], else[]}` |
| reward / failure | verbs flag, items, standing, block_standing, debt_pct, mod, trait, pollution, suspicion... | `passive_mark`, `passive_deed`, `gear`, `heal`, `trait_event`, `tension` |
| placeholders | `{dead}` (W4) | `{who}` (ref), `{n}`, `{item}`, `{giver}` resolved at build time |
| instance ids | `sim.defs.quests[id]` lookups in 5 places | `QuestLog._qdef(id)` = generated first, then defs |
Full verb/cond list with signatures: [integration.md](integration.md). Quest-log hash: generated instances
appear in `state_parts` as `[id, template, sorted params]` only (idle runs hash nothing new).

### Instance skeleton (what the builder emits)
```
offer:  text, options {acc[, acc2], dec}, expire_days E, default "dec"
  acc.effects = [cost..., pick/snap/spawn..., flag "sq.<id>.open"]  then "check" delay 0.25
  dec.effects = [decline cost..]                                      (finish)
check:  wait = [goal_met, {since:{stat:"day", n:D}}]  wait_max_days D+1
        effects = [{verb:"if", cond:goal_met, then:[win..., letter], else:[fail..., letter]}]
```
"Hold" goals (stay quiet, nobody dies) have `goal_met` evaluated only after the time-up cond (the wait
array's second entry is the trigger; the `if` decides). Reports are made at the next dawn: the daily
poll of F6 is the "roll call" — in-fiction, the Warden counts errands at roll call.

## 3. Template schema (`data/side_quests.json`)
```
"sq_ledger_errand": {
  "giver": "clerk",              // see section 4; sets icon, voice, Standing block, availability cond
  "goal": "deliver",             // goal module (section 5): supplies goal_met, snap, labels
  "twist": "",                   // optional twist module (section 6)
  "weight": 3, "cooldown_days": 12, "min_day": 8, "max_day": 0,
  "requires": {conds...},        // AND dict, same cond language as quest triggers
  "avoid_path": [], "only_path": [],
  "params": {"n": {"base": 6, "per_day": 0.12, "min": 4, "max": 16}, "days": 4},
  "load": 1,                     // slots used of max_open 2
  "text": ["line", "line", "line"],        // offer text, each line <= 70 chars
  "options": {"acc": {...}, "dec": {...}}, // effects in shorthand (section 8)
  "win": [...], "fail": [...],             // effect lists
  "chain": {"to": "sq_x", "on": "win", "p": 1.0, "delay_days": 2}
}
```
Authoring shorthand (used in the pool files) is compiled 1:1 into this JSON by the content worker.

## 4. Giver pool (voice, availability, Standing link)
| giver | voice (one line) | available when | Standing link |
|---|---|---|---|
| `lifer` | old forms, never hope | lifer block alive | lifer block |
| `clerk` | margins, loopholes, buyers | clerk block alive | clerk block |
| `zealot` | judgment, sabotage | zealot block alive | zealot block |
| `informant` | smiles, writes things down | informant alive (Q13 not purged) | informant_standing |
| `fresh` | scared, honest, asks | fresh_fish alive | fresh_fish block |
| `warden` | PA, passive voice, invoices | always (`pa_silent` = 0) | none; suspicion/debt |
| `guard` | a named guard (Pell/Okoro), bored, bribable | always | suspicion |
| `ferry` | smuggler voice on the guard frequency | `path_escape` or `contraband_on` or d20 | credit/suspicion |
| `auditor` | clipboards | audit tier >= 1 done | suspicion |
| `procurator` | shuttle voice, polite menace | Q14 done | path-specific |
| `pilgrim` | Brother Oto's order | Q2 done | zealot block |
| `echo` | a dead inmate's hum from refined batches | an inmate has died AND pollution > 25 % | none; mood, marks |
| `planet` | the essence itself ("it hums") | any refining done | pollution / traits |
| `drone` | Metropolis pilot / wreck | >= 1 metro raid survived | defiance |
Rule: a giver that is *dead or purged* is not offered. An errand from a block never fires while that block
is under 15 Standing (walkout logic owns that block then).

## 5. Goal modules (what the player must do)
Each module = `accept` effects (snapshot/spawn) + `goal_met` cond + label for the strip. `D` = window days.
| goal | player does | accept | goal_met | strip label |
|---|---|---|---|---|
| `deliver` | have N item in storage at check | none | `stored {item,n}`; win consumes `items -n` | "4/6 refined" |
| `build` | build/finish building X (count absolute: now + 1) | none | `built {id,n}` | "Build: turret" |
| `survive` | live through W waves | `snap waves` | `since {waves,W}` | "Waves 1/2" |
| `protect` | keep NPC `guest` alive D days | `spawn_colonist as guest` | wait `[ref_dead guest, since day D]`, then `if not ref_dead guest` | "Guest safe" |
| `escort` | protect + the guest leaves at the end (`remove_colonist transfer`) | as protect | as protect | "Escort: 3 d" |
| `investigate` | send the best-fit inmate (picked by trait) | `pick who by=trait:..` | time-up then `gamble p` with `p_traits` bonus | "Survey: 2 d" |
| `smuggle` | sell/hand N refined to the Ferry or a guard | `items -n`, `sus +x` | time-up, `gamble` on suspicion | "Cargo out" |
| `cure` | spend N `cure` on the sick/mutated | `items cure -n` | `heal` at accept; win flag | "Treated" |
| `hunt` | kill K creatures | `snap kills` | `since {kills,K}` | "Kills 2/5" |
| `scrub` | push pollution under X % (decon/waste handling) | none | `pollution_below x` | "Pollution 31 -> 25 %" |
| `hold` | refine at most X batches in D days | `snap refined` | time-up, `if since{refined,max:X}` | "Quiet: 2 d left" |
| `ward` | nobody dies in D days | `snap deaths` | time-up, `if since{deaths,max:0}` | "No deaths" |
| `repair` | repair K things | `snap repairs` | `since {repairs,K}` | "Repairs 3/5" |
| `mine` | mine N ore | `snap ore` | `since {ore,N}` | "Ore 120/300" |
| `recruit` | take a transfer into the block | `spawn_colonist as guest` + flag | `ref_alive guest` at end | "Newcomer settles" |
Goals only read things normal play already produces (stock, buildings, waves, kills, deaths, refined) — no
new jobs, no new map markers. That is the cost control (see integration).

## 6. Twist modules (change the shape; optional, ~35 % of instances)
| twist | effect on the instance | rewards x |
|---|---|---|
| `rush` | `days` x 0.5, expire 1 d | x1.5 |
| `tainted` | goods or site add `pollution +2..4 %` on accept | x1.3 |
| `witnessed` | `sus +6` on accept (or Informant reports: `informant_alive`) | x1.3 |
| `rival` | a second giver posts the opposite errand (cond: both open -> only one can win; the loser's block `-6`) | x1.4 |
| `echo` | the guest/target carries a dead inmate's name (`{dead}`); win gives a mood thought | x1.0 +mark |
| `bait` | a mimic or crawler pair arrives at the check (`spawn_enemy`) | x1.5 |
| `unmarked` | no hint on the accept button (hidden cost revealed at the win/fail letter) — max 1 per 3 errands | x1.6 |
| `debt` | reward is a debt cut (<= 2 %), fail is debt + (<= 2 %) | x1.0 |
| `long` | `days` x 1.5, goal n x 1.4 | x1.3 |

## 7. Scaling (day / pollution / path / Standing)
`k_day = clamp(0.5 + day/30, 0.7, 3.0)`, `k_poll = 1 + pollution_fraction` (0-1), `k_path` = 1.15 on Fight
(raids), 1.0 else. Parameter = `base + per_day * day`, clamped; item counts additionally x`k_poll` for
`deliver` (a dirty planet makes everything dearer). Reward value (in refined-units, table 8) is
`cost_value * (1.25 + risk_bonus) * twist_x`, where `risk_bonus` 0.1 per chance of death, 0.1 per
pollution point of 5 %. **Standing gate**: a block's elder offers a better reward tier when that block's
Standing >= 60 (x1.2 item reward, +1 mark option) and a worse, clingier one when <= 30 (reward x0.8,
failure Standing -50 % stricter) — errands are where Standing becomes visible as money.
Path: `only_path` / `avoid_path` filter templates; before Q14 (no path) errands are path-neutral.
Caps: debt effect always within the engine's 2 %/10 % caps; no single errand pays more than ~20 % of the
refined produced in its window (`reward_cap_frac`, checked by the content validator test).

## 8. Shorthand used in the pool files (compiles to JSON verbs)
| shorthand | verb |
|---|---|
| `it refined_essence -8` | `{verb:items, item, n}` (negative spends) |
| `st lifer +8` / `bst strong -6` | `standing {block,delta}` / `block_standing {target,delta}` |
| `debt +1` / `debt -1 who` | `debt_pct {pct, who?}` |
| `mood thought [who]` / `moodb block thought` | `mood` / `mood_block` |
| `mod name v d` | `mod {name, value, days}` |
| `pol +3` | `pollution {value:0.03}` |
| `sus +6`, `cr +2`, `def +4` | suspicion, credit, defiance |
| `flag x` | `flag` |
| `tr who t_id` / `trx who name` / `trdel who t_id` | `trait` (with `who`) / `trait_event` / `trait_remove` |
| `mark who n` / `deed who d_id` | `passive_mark` / `passive_deed` |
| `gear base rarity` | `gear` (loot roll) |
| inline pick | any `who` may be `@best:<skill>`, `@downed`, `@oldest`, `@lowest_mood` (picked at effect time, sorted by value then id) |
| `pick who by` | `pick {as, by}`; `by` = `lowest_mood`, `trait:t_x`, `charge:t_charge_x`, `skill:mining`, `random` |
| `snap stat` | `snap {stat}` |
| `gamble p [win] [lose]` | `gamble` (optional `p_traits:{t_id:+0.1}` on `who`) |
| `if cond [then] [else]` | `if` |
| `ten +8` | `tension` (director meter) |
| `ln "Title" "text"` | `letter` |
Conds: `day>=8`, `pol>40`, `blk(clerk)<30`, `path=fight`, `has(t_x)`, `stored(item,n)`, `built(id,n)`,
`since(stat,n)`, `ref_dead(who)`, `informant`, `sus>40`, `ten<30` ... = existing conds + new ones.

## 9. Rewards, failures, value table
Value in "refined-units" (ru) for balancing and the validator test: refined_essence 1, plate 0.5,
parts 0.8, machine_parts 1, meal 0.25, raw_food 0.2, cure 6, ai_chip 4, essence_bloom 1.5, gear uncommon 8,
debt -1 % 5 (cap 2 %), Standing +10 = 3, mark = 5, trait good = 6, scar = -6, pollution +1 % = -2.
**Reward classes** (each template names one primary): `items`, `gear`, `debt`, `standing`, `mark`, `deed`,
`trait` (a good acquired trait or removing a scar: `trdel who t_resigned`), `mod` (a timed buff such as
`refine_mult`, `despair_mult 0.9`), `intel` (reveal next wave origin = `scout` via a mod flag), `person` (a
specialist joins). **Failure classes**: `standing`, `debt+`, `scar` (`tr who t_marked`), `mood` thought,
`wave` (`mod wave_mult 1.1 5d`), `loss` (guest dies, items seized), `suspicion`, `pollution`. Failure is
priced about 0.6-0.8x of the reward; death of the *guest NPC* is allowed, of a regular inmate only by an
explicit option the player chose (cost quoted).

## 10. Selection: weights, cooldowns, anti-repetition
`weight_eff = base * band_mult(tension) * path_mult * recency * giver_gap * need_boost`
- `recency = 1 - exp(-days_since_template / cooldown_days)` (0 if never fired = 1).
- `giver_gap`: x0.3 if the same giver spoke in the last 4 days; x0 if offer from the same giver is open.
- `goal_gap`: x0.4 if the same goal module fired in the last 2 errands.
- `need_boost` x1.5 when the template's reward matches a shortage the director sees (parts < 5, meals < 4,
  a block under 35, a scar-heavy colony); never reveals the logic.
- `max_per_game` per template (2-3 for story-ish ones). Global gate: `open < max_open (2)`,
  `days_since_last_offer >= offer_gap_min (3)`, no pending card, no wave warning.
- Candidate list is built in sorted id order; one `randf` picks; a fixed number of draws per check
  (see 11).

## 11. Determinism
- Director rng `_drng` seeded `sim.seed_value ^ 0xD1C7011` (own stream like `Storyteller._prng`, so classic
  rolls and goldens never shift). Each check draws exactly 3 floats (chance, pick, spare).
- Instance params use a **child rng** seeded `hash([seed_value, instance_no, template_id])`: the builder
  never touches `sim.rng`. Params are stored concrete (`n`, `item`, `days`, giver ref).
- Effects run by QuestLog still use `sim.rng` only for `gamble`/`chance`, as today (one draw each).
- Candidate iteration: sorted ids. Colonist picks (`pick`): sorted by value then id (same as `trait` verb).

## 12. Chaining into story lines
`chain {to, on:"win"|"fail"|"any", p, delay_days}` schedules the next template as a forced offer (bypasses
the offer gap, not the one-card rule). A line = 2-3 templates sharing a flag (`line_courier`). Lines in the
pool: **Courier** (SQ05 -> SQ06 -> SQ07, Ferry), **Seat Nine** (SQ12 -> SQ13, a dead man's bunk, echo),
**Quiet Ward** (SQ21 -> SQ22, a sick block), **Paper Trail** (SQ17 -> SQ18, Clerk and Auditor). Lines pay a
closing bonus (a mark or a deed) and can touch traits, never clues.

## 13. What it never does (guardrails)
No clue flags, no path change, no Q14/Q15/Q17 prerequisites; no text that contradicts the bible (creatures
are former inmates only *after* Q15 — before it, errand text says "creatures", "the dead", "the hum"). No
more than 1 permanent trait per 10 days from errands. No errand needs a new job type, a new map overlay or
a new building. Everything is skippable at a quoted price.
