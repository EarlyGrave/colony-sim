# Earning marks, budget, respec

All numbers are direction, not balance (owner rule). Data: `data/passives_v2.json` → `marks`, `deeds`, `respec`.

## Sources
| source | rule | marks | module call (integration) |
|---|---|---|---|
| Skill milestone | per skill, once each: L3 → 1, L6 → 2, L10 → 3 (`marks.milestones`) | ≤ 6 per skill, ≤ 48 total (never reached) | `on_skill_level(st, skill, level)` from `ProgressionSystem._on_leveled`; `set_baseline(st, skill, join_level)` at spawn (veterans earn only *new* milestones, like `PerkSystem.join_level`) |
| Deeds (records) | thresholds on `ColonistSystem.records[c.id]`: kills 1/10/50, waves_survived 3/10, ore_mined 500/2000, refined 20/100, repairs 10, downs 1 | 1–3 each, once | `check_records(st, records)` on `record_changed` (or daily) |
| Deeds (counters) | installments 1, rescues 1, tends 10, debt_cleared 1, quiet_days 30 | 1–3 each, once | `bump_counter(st, key, n)` from the bus: `debt_paid`, `colonist_rescued` (carrier), `colonist_tended` (doctor), `day_started` (+1 quiet day; `mood_break_started` resets the counter) |
| Quest reward | story lines (`docs/story`) give marks or a deed | per quest, 1–3 | quest verbs `passive_mark {who, n}` → `earn`, `passive_deed {who, id}` → `grant_deed` |
| NG+ dossier | the best inmate's `marks_spent` ≤ `dossier_carry_max` 4 banked for the veteran; allocated keystones are "known for" (cost 0 next run) | ≤ 4 + free keystones | `dossier_carry(st)` in `Legacy.ng_snapshot`, `apply_dossier(st, d)` in `start_opts` |

Deed list (16): First Installment, First Blood, Ten Notches, Yard Legend, Still Standing, Old Hand, Five Hundred
Rocks, Mountain Mover, Stack Hand, Stack Boss, Duct Tape, Got Up Again, Carried a Friend, Ten Patients, Paid in
Full, Thirty Quiet Days (text and thresholds in table.md). Deeds post a one-line letter ("Varga: Still Standing —
1 mark") only for 2+ mark deeds; 1-mark deeds go to the log line (phone: no spam).

## Budget model (why 17 marks per detail)
Using `tools/skill_model.gd` numbers (days to L3/L6/L10 for a full-time worker: ~3 / ~14 / ~45 days at passion
×1) and the bot's survival runs (3 waves by day ~12, 10 waves by day ~35):
| day | milestones | deeds | total ≈ | buys |
|---|---|---|---|---|
| 10 | main skill L3 (1), second skill L3 (1) | first installment, first blood | 4 | entry + three minors: the first row of a card |
| 25 | main L6 (+2), second L3, third L3 | 3 waves, 10 kills, 500 ore / 20 batches | 9–10 | two notables → keystone visible |
| 45 | main L10 (+3), second L6 (+2) | 10 waves, got up again, rescuer | 16–19 | detail keystone **or** a bridge, plus a few minors |
| 60+ (shuttle window) | third L6 | 2000 ore / 100 batches, debt cleared (3) | 22–26 | 1 detail complete + a second card started; two keystones |
So a veteran specialises in one detail and dips into a neighbour — exactly the bridge keystone shape. Nobody fills
two cards in one sentence; the dossier (≤ 4 marks + free keystone) is what makes the second run faster.
Knobs if the model is wrong: `marks.milestones`, deed `marks`, `cost` per tier (the module reads all from data).

## Respec economy
`respec_cost(st, path)` → `{item: refined_essence, count: ceil(per_mark × marks_spent × path_mult), standing:
keystone_standing × keystones, lockout_days: 3}`. `path_mult`: Submit 0.5, Fight 1.0, Escape 1.5, none 1.0.
- Why refined essence: it is the colony's only universal currency (perks respec, research, the shuttle quota),
  so a respec competes with the quota — the owner's "debt / essence / Warden favour" trio collapses to essence ×
  path. On the Submit path the Warden *sells* retraining cheaply (he wants pliable inmates); on the Escape path
  every refined unit is also escape credit, so a respec hurts twice.
- Why Standing: forgetting a keystone is a public change of character; the inmate's block loses 5 Standing per
  keystone (`block_system._change`), which can tip a block toward a walkout — a real cost, never a death spiral.
- Lockout 3 days: the inmate is "in retraining", marks cannot be spent (`can_allocate` → `locked`), work goes on.
- Free undo inside one day (`undo_grace_ticks` 1800) if nothing depends on the node: misclick guard for touch.
- The module never touches inventory or Standing; the integration pays first, then calls `respec(st, now, tpd)`.

## Determinism and replay
Every mark change and allocation is a `Simulation` command in the integration (`allocate_passive(cid, id)`,
`undo_passive`, `respec_passives`) or a bus-driven deterministic award. No rng. `state_hash(st)` includes the
allocation order so two replays with different click order differ (as they should: grace undo depends on it).
