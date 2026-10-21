# Integration plan (one wave, 4 workers)

Everything behind `balance.director_enabled = false` (new key). With the flag off: `Defs` does not load
`side_quests.json` / `events_v2.json`, `Simulation` has no `director` member, `QuestLog` new members are empty and
absent from `state_parts`, goldens byte-identical. Decided without owner, review.
Total size: about 1100 lines GDScript, 1500 lines JSON, 600 lines tests. Cost M+M+M+S. Sonnet workers.

## 1. Workers and file ownership (disjoint)
| worker | owns | does |
|---|---|---|
| **W1 engine** | `sim/quests/quest_log.gd` (`# region SQ`), `sim/society/society_conds.gd` (region SQ), `tests/test_side_quest_engine.gd` | instances (`_qdef`, `generated`), offer expiry, verbs and conds below, `{who}` text, state_parts |
| **W2 director** | `sim/storyteller/director.gd` (new), `sim/quests/quest_generator.gd` (new), `sim/core/simulation.gd` + `defs.gd` (region SQ: one member, one load, one tick call), `data/balance.json` (`director` block, flag), `tests/test_director.gd` | tension meter, roll, template pick, builder (templates -> instance dict), child rng, cooldowns, chains |
| **W3 content** | `data/side_quests.json`, `data/events_v2.json`, `data/mood.json` (4 new thoughts), `tests/test_side_quest_content.gd` | compile the pool files (SQ01-32, EV01-44) to JSON; content validator test |
| **W4 view + tools** | `view/quest_sheet.gd` (expiry line, errand strip), `view/hud.gd` (region SQ: notices badge), `tools/director_report.gd`, `tools/bot_*.gd` knob, `tests/test_director_phone.gd` | card timer, hints, errand strip, report tool, bot flag `--director=1` |
W3 may start from the pool docs on day 0 (JSON has no code dependency); the validator test needs W1/W2 merged
(`tools/run_tests_quick.sh` after each merge). Order: W1 -> W2 -> W3 test -> W4. Shared files only inside
`# region <agent>` blocks.

## 2. New verbs (QuestLog `_apply_effects`)
| verb | args | does |
|---|---|---|
| `if` | `cond{}`, `then[]`, `else[]` | `_trigger_ok(cond)` then apply a list (nested depth 2) |
| `snap` | `stat` | stores `flags["snap.<qid>.<stat>"]`-style counter baseline in a `snaps` dict |
| `pick` | `as`, `by` | picks a living inmate (sorted by value, then id), stores in refs; none = effect list aborted |
| `trait` (extend) | `who`, `id` | existing verb gets `who`; `trait_remove` {who,id}; selector `@best:<skill>`, `@downed`, `@oldest`, `@lowest_mood`, `@newest` |
| `trait_event` | `who`, `name` | `TraitSystemV3.event(c, name)` (no-op if traits v3 off) |
| `passive_mark` / `passive_deed` | `who`, `n` / `id` | `PassiveTreeV2.earn` / `grant_deed` (no-op if passives v2 off) |
| `gear` | `base` or `any`, `rarity` | loot roll through the existing gear roller (`sim.rng`, one draw count fixed) |
| `heal` | `who` or `all` | clears one illness / tends a wound (HealthSystem) |
| `sick` | `who`, `ticks` | `health.add_illness(c, "fever", 1.0, ticks)` |
| `wear` | `amount`, `target:"random"` | `buildings.wear` on a machine (sorted pick via `sim.rng`) |
| `cave_in` | `cells` | the storyteller's `_cave_in_cell` x cells |
| `scout` | none | the storyteller `scout` op (next wave origin in the log) |
| `xfer` | `who` | `debt._remove(c, "transferred")` |
| `tension` | `n` | `director.tension += n` (events/templates only; clamped 0..100) |
| `chain` | `to`, `p`, `delay_days` | director queues a forced offer |
Existing, reused as is: flag, letter, mod, items, mood, mood_block, debt_pct, spawn_colonist(as), remove_colonist,
pollution, gamble, spawn_enemy, standing, block_standing, ref_block, informant_standing, suspicion, credit,
defiance. `gamble` gets optional `p_traits {t_id: delta}` evaluated on `who`.

## 3. New conds (trigger / wait / requires / `if`)
`stored {item,n}` · `built {id,n}` · `since {stat,n}` or `{stat,max}` (stat: day, waves, kills, refined, ore,
deaths, raids, repairs; uses `snap`) · `ref_dead {who}` / `ref_alive` · `has_trait {id}` (any living; `t_` ids,
false when v3 off) · `any_sick` · `pollution_below` · `colonists_over/_under` · `tension_below/_above`
(director) · `wave_pending` · `path {id}` · `dead_exists` · `gear_owned` (exists). `_requires_ok` already routes
unknown keys through `_conds`, so each is one `register_cond` line in a `# region SQ` block.

## 4. Engine changes (W1, small and local)
1. `_qdef(qid)`: `generated.get(qid, sim.defs.quests.get(qid, {}))`; replace the 5 `sim.defs.quests[...]` reads in
   `start`, `_enter`, `_resolve`, `_f6a_limit`, `_f6a_wait_ok`.
2. `start_instance(qid, tpl_id, params, def)`: registers `generated[qid]`, then `start(qid)`.
3. Offer expiry: a beat may carry `expire_days` + `default` (option id). `pending` entry gets `expires` tick;
   `_on_day` answers expired offers with the default (through `answer`, same code path as the player).
4. Text: `_w4_text(t, qid)` also replaces `{who}` with the ref'd colonist name; build-time placeholders are done by
   the generator.
5. `state_parts`: appends `["gen", [[qid, tpl, sorted_params], ...], snaps, expires]` only when non-empty, so
   idle/off runs hash identically.
6. Replay: instances rebuild from `(tpl, params)`; the replay hash test covers an errand in flight.

## 5. Director (W2)
```
Director (RefCounted, sim.director when flag on)
  tension: float; _drng (seed ^ 0xD1C7011); counters: last_offer_day, cat_last{}, tpl_last{}, giver_last{}
  tick(): twice a day: 3 fixed draws -> gate (cards pending? band? card_gap?) -> pick category/pool ->
          candidate filter (requires, cooldowns, vetoes) -> weighted pick (sorted ids) -> build -> start_instance
  signals: wave_started, colonist_died, metro_raid_started, quest_resolved (chain) -> tension deltas
  daily: decay, band update, expire chains
```
Balance block (`balance.json director`): `enabled`, `checks_per_day` 2, `chance` 0.35, `decay_ordinary` 4,
`decay_quiet` 8, `bands` [20,50,75], `band_mult` table, `card_gap_min` 0.75, `max_cards_per_day` 2,
`max_open_errands` 2, `offer_gap_min` 3, `first_offer_day` 6, `classic_mult` 0.5, `wave_buffer_days` 1.5,
`harm_vetoes`. Hooks: `Simulation.step` calls `director.tick()` after `storyteller.tick()` (order stays);
`Storyteller._roll_classic` multiplies its chance by `classic_mult` when the director is on.

## 6. Data files
`data/side_quests.json`: `{templates:{...}, givers:{...}, goals:{...}, twists:{...}, values:{...}}` (schema in
generator.md). `data/events_v2.json`: `{events:{...}, categories:{...}, tension:{...}}`. New thoughts in
`mood.json`: `warm_night` (+4, 2 d), `dust_lung` (-4, 2 d), `heard_the_hum` (-5, 3 d), `found_something`
(+4, 2 d). Loader globs nothing new: `Defs.load_from` reads both files only when the flag is on.

## 7. Tests (all in `tests/`)
- `test_side_quest_engine.gd`: `if` both branches, `snap`/`since`, `pick` determinism (same seed same pick),
  expiry answers the default, instance rebuild equals original, `state_parts` unchanged when flag off.
- `test_director.gd`: tension bands move on a scripted wave; harm veto inside warning window; never two harm>=2
  active; same seed = same card sequence over 40 days; one card at a time; chain delivered.
- `test_side_quest_content.gd` (validator over the JSON): every text segment <= 70 chars, 2-3 options, every
  option has `hint`, verbs and conds are known, ids unique, thoughts exist, reward value <= `reward_cap_frac` of
  cost x2 (value table), no clue flags, `debt_pct` within caps, every chain target exists, every `pick` selector
  is valid, >= 30 templates and >= 40 events, per-category counts.
- `test_director_phone.gd`: card with timer fits 844x390, buttons >= 64 px, errand strip does not overflow.
- Force-test per template: `tests/scenario.gd` helper `force_template(id)` runs offer -> accept -> goal -> check for
  win and fail (one parametrised test over the pool, ~76 cases).

## 8. Bot knob and ship checks
`tools/director_report.gd` (events.md section 8) + bot flag `--director=1` (and `--director_choice=first|price|decline`
to answer cards: the bot accepts options whose cost it can pay, never gambles below 0.5). Ship checks before merge to
`main`: 10 seeds x 60 d: alive aggregate not lower than off by > 2; cards per day 0.6-1.0; errand offer count 6-12;
win rate of accepted errands 50-80 % (balance by the value table, not by eye); `tools/web_smoke.py` once.
New content merges only with bot numbers (CLAUDE.md rule 9). GDD status tags updated in the same push.

## 9. Risks
| risk | mitigation |
|---|---|
| Determinism: new rng draws shift existing streams | own `_drng` stream; child rng for params; fixed 3 draws per check; picks use sorted ids; flag off = no draws at all |
| Goldens drift | members absent when off; `state_parts` untouched; `make_golden --regen` never needed; add one golden with the flag ON (separate file) |
| Card spam on a phone | one pending card, `card_gap_min`, band multipliers, `max_cards_per_day`; the report tool gates the batch |
| Errands trivialise economy (free parts, debt) | value table + `reward_cap_frac`; debt effects within engine caps; hints quote prices |
| Harm events kill the colony before a wave | hard vetoes (wave window, broken link, recent deaths); no event spawns more than 2 enemies |
| Trait/passive verbs when v3/v2 are off | each is a no-op guarded by `sim.get("traits_v3") != null`; templates that need them `requires` has_trait |
| Text > 70 chars after substitution | builder truncates numbers only; validator tests worst-case `{n}` width; `{who}` names <= 14 chars |
| `wait` polling is once a day | stated in the UX ("reported at roll call"); goals are day-scale by design |
| Story consistency (revelation arc) | pool never sets `clue_*` flags; texts avoid claiming creatures were people before Q15 |
| Interaction with Q1-Q16 pending cards | director yields to any `pending` entry; main quests have priority; errand expiry extends while a main card is open |
| Mimic events and `spawn_enemy` | EV31 only after Q8; enemy count capped; quest-only mimic stays out of raid tables |

## 10. Owner questions (decided without owner, review)
1. Keep classic `events.json` rolling next to the director (default: yes, chance x0.5)?
2. May errands grant permanent traits (default: yes, one per 10 days, always opt-in via a quoted button)?
3. Show the tension meter to the player (default: no, debug only)?
4. Hidden-cost twist `unmarked` (default: allowed, max one per three errands)?
5. Do errands pause after Q14 until the path sheet is closed (default: yes, 1 day)?
