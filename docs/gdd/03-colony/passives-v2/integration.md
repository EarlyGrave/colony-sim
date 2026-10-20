# Integration plan (flag ON) — what the next batch touches

Today: `balance.passives_v2_enabled` false, `PassiveTreeV2` is not referenced by any sim or view script, goldens
unchanged. The module is pure (no Simulation inside), so integration is a thin `PassiveSystem` wrapper plus one
hook line per stat. Worker split: W1 system + bus + commands, W2 hook lines (+ caps), W3 UI panel + bot + ship.

## W1 — `sim/perks/passive_system.gd` (new) + registration
- `Simulation`: `var passives: PassiveSystem` created after `perks`; `tick order` unchanged (no tick needed except
  nothing — the system is event-driven). Guard every public method with `enabled()` =
  `defs.balance.get("passives_v2_enabled", false)`; when off, `mod()` returns 0.0 and nothing listens.
- `Defs.load_from`: `passives_v2 = _load_json(dir + "passives_v2.json")  # region passives_v2` (one line; the
  module accepts the dictionary: `PassiveTreeV2.new(defs.passives_v2)`).
- `Colonist`: `var passives: PassiveTreeV2.State = null  # region passives_v2` (created on demand, like `perks`).
- Bus (`autoload/event_bus.gd`): `passive_allocated(colonist_id, passive_id)`, `passive_marks_changed(colonist_id,
  free)`, `passive_deed(colonist_id, deed_id)`.
- Listeners → module calls: `skill_leveled` → `on_skill_level`; spawn (`ColonistSystem.spawn`) → `set_baseline`
  per skill at join level; `record_changed` → `check_records`; `debt_paid` → `bump_counter("installments")`
  (+ `"debt_cleared"` when `DebtState.remaining() == 0`); `colonist_rescued` → carrier `"rescues"`;
  `colonist_tended` → doctor `"tends"`; `day_started` → `"quiet_days"` +1 for every inmate (reset to 0 on
  `mood_break_started`).
- Commands on `Simulation` (replay-safe): `allocate_passive(cid, id) -> bool`, `undo_passive(cid, id)`,
  `respec_passives(cid)` (pays `respec_cost` with `items.consume_stored` + `blocks._change(block, -standing)`,
  then `tree.respec(st, tick, TICKS_PER_DAY)`), `grant_passive_marks(cid, n, reason)` for quest verbs.
- Quest verbs (`sim/quests/*`): `passive_mark {who, n}`, `passive_deed {who, id}`.
- Save: `state_parts()` → `[cid, st.to_dict()]` per inmate; `state_hash` includes `tree.state_hash(st)`.
- NG+: `Legacy.ng_snapshot` adds `dossier.passives = tree.dossier_carry(st)` for the dossier inmate;
  `start_opts` → `apply_dossier`.
- `tools/skill_model.gd`: print marks by day 10/25/45/60 (earning.md budget) for 3 seeds.

## W2 — hook lines (each `# region passives_v2`, one line, next to the perks/traits read)
`P(c, s)` = `sim.passives.mod(c, s)` (0.0 when off → byte-identical goldens with the flag off is still required:
run `--filter=test_golden` after every hook).
| stat | file:line | today | with passives |
|---|---|---|---|
| mining_speed | sim/jobs/mine_job.gd:27 | `1.0 + perks.mod(c,"mining_speed")` | `+ P(c,"mining_speed")` |
| ore_yield | sim/jobs/mine_job.gd:39,54 | perks | `+ P` |
| work_speed | sim/jobs/job_system.gd:190 | perks × traits shift | `+ P` inside the `1.0 +` |
| build_speed / build_cost / building_hp | build_job.gd:25, building_system.gd:427,437 | perks | `+ P` |
| carry | trait_system.gd:47 `carry_cap` | traits | `+ P(c,"carry")` in the same multiplier |
| move_speed | colonist.gd:62 | perks + traits | `+ P` |
| hunger | needs_system.gd:29 | traits | `+ P` |
| rest_gain **(new)** | needs_system.gd:38 `rest_tick` | — | `gain *= 1 + P(c,"rest_gain")` |
| threat_attract | threat_system.gd:141 | perks | `+ P` |
| operate_speed / craft_speed | operate_job.gd:28 | perks (stat by work type) | `+ P(c, stat)` |
| repair_speed **(new)** | repair_job.gd:30,55 | — | `work_tick(...) * (1 + P(c,"repair_speed"))` |
| machine_breakage | building_system.gd:193 `breakage_mult` | traits | `× max(0, 1 + P)` |
| waste_mult | building_system.gd:174 | perks, cap -0.4 | `PerkHooks.scaled(..., 1 + max(-0.4, perks + P))` — cap on the **sum** |
| contamination_per_batch | contamination_system.gd:28 | perks, cap -0.4 | same: cap on the sum |
| mutation_risk | mutation_system.gd:429 `mutation_mult` | traits | `× max(0, 1 + P)` |
| craft_input / craft_quality | building_system.gd:153, quality_system.gd:57 | perks | `+ P` |
| quality_tier | quality_system.gd:63 `quality_shift` | traits | `+ roundi(P(c,"quality_tier"))` |
| gear_wear **(new)** | equipment_system.gd:253,270 | `loss_per_hit_taken` / `loss_per_attack` | `loss *= max(0, 1 + P(c,"gear_wear"))` (only when `wear_enabled`) |
| ammo_use | ammo.gd:83 | perks | `+ P` |
| hit_chance / unarmed_hit / melee_damage / unarmed_damage / crit_chance / attack_speed | combat_system.gd:30,34,177,179,180,168 | perks / traits | `+ P`; crit: rng drawn only when the total > 0 (keep the PW4 rule) |
| dodge_chance | threat_system.gd:649,1081 | perks | `+ P` |
| damage_taken | health_system.gd:28 | perks | `+ P` (cap -0.5 on the sum) |
| armor_flat | combat_system.gd:106,111 (cached stat block) | traits | `+ P` — folded into the resum, no per-hit loop |
| flee_threshold | job_system.gd:35 | traits | `traits.mod + P > -1.0` |
| tend_quality / heal_speed / infection_chance | health_system.gd:71,78,79,185,208 | perks | `+ P` (doctor at 71–79, patient at 185/208) |
| mood_base / break_chance / thought_injured | mood_system.gd:54,92,40 | traits | `+ P` |
| despair_mult | debt_system.gd:155 | traits | `+ P` |
| installment_pct | trait_system.gd:87 `installment` | traits | `+ P` (cap -0.4 on the sum) |
| standing_gain | block_system.gd:73 | traits | `+ P` |
| suspicion_gain **(new)** | contraband.gd:194 `covert_sale`, :212 `_suspicion_day` | `suspicion_per_sale` | `× max(0, 1 + P(seller,"suspicion_gain"))`; seller = the top stash holder (`_top_holder`) |
| stash_cap **(new)** | contraband.gd:50 `skim_budget` | cfg | `+ roundi(sum of P(c,"stash_cap") over inmates)` |
| sale_price **(new)** | contraband.gd:201 | `escape_credit += n` | `+= PerkHooks.scaled(seller,"sale_price", n, 1 + P)` |
| xp_mult_* / xp_mult_all | progression_system.gd:30 | `traits.xp_mult` | `× sim.passives.xp_mult(c, skill)` |
Everything above is additive on an existing `1.0 + ...` so the flag-off value 0.0 is exact (no float drift).
Consumers that cache (`armor_flat` in the combat stat block, `totals` in equipment) must invalidate on
`passive_allocated` — `combat_system.resum(c)` already exists for traits.

## W3 — UI, bot, ship checks
- `view/panels/passive_board.gd` (new, touch-first): header (inmate, marks free, keystones 2/2), 6 detail chips,
  one card (3×6 grid of 64 px buttons, icon = `assets/sprites/passive_<id>.png`, frame alpha by state), seam
  half-diamonds for the two bridge keystones, bottom sheet on tap: name, desc, effect lines, "Requires …" from the
  reason code, button Allocate / Undo (grace timer) / Respec (cost line). Opened from the colonist sheet ("Record"
  button, NEW badge when `marks_free > 0`), like the perk panel.
- Letters: deed ≥ 2 marks → `letter_received`; milestones already post letters (add "+n marks").
- Bot (`tests/qa_bot.gd`): knob `passive_pick` = "first allocatable on the card of the best skill"; keystone when
  allowed. Balance from a table: extend `tools/balance_report.gd` with a column "marks spent / keystones" and
  `tools/combat_model.gd` with Dead Man Walking / Armourer's Pride rows before tuning.
- Ship: `tools/web_smoke.py` taps the Record button; `tests/test_phone_layout.gd` gets the board at 844×390 DPR3;
  goldens regen only after the flag is turned on (intended change, list the changed ticks in the report).
- Perf: `mod()` is cached per state and cleared on change; hook lines read it in hot loops exactly like
  `perks.mod` (one dictionary lookup when cached, 0 when the inmate has no state). No per-tick work in the system.

## Rollback
Flag back to false → every hook adds 0.0, the board button hides, saves keep the `passives` part (ignored).
