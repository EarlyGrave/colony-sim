# Integration plan (flag ON) — what the next batch touches (r2)

Today: `balance.passives_v2_enabled` false, `PassiveTreeV2` is not referenced by any sim or view script, goldens
unchanged. The module is pure (no Simulation inside), so integration is a thin `PassiveSystem` wrapper, one hook
line per numeric stat and one guard per **rule flag**. Worker split: W1 system + bus + commands, W2 numeric hook
lines (+ caps), W3 rule guards (grouped by system), W4 UI panel + bot + ship. Rule guards are the new part in r2:
each is `if sim.passives.rule(c, "<x>")` on an existing line, listed in §W3 with its file:line and whether the
line exists today.

## W1 — `sim/perks/passive_system.gd` (new) + registration
- `Simulation`: `var passives: PassiveSystem` created after `perks`; tick order unchanged (event-driven, no tick).
  Guard every public method with `enabled()` = `defs.balance.get("passives_v2_enabled", false)`; when off,
  `mod()` returns 0.0, `rule()` returns false and nothing listens.
- `Defs.load_from`: `passives_v2 = _load_json(dir + "passives_v2.json")  # region passives_v2` (one line; the
  module accepts the dictionary: `PassiveTreeV2.new(defs.passives_v2)`).
- `Colonist`: `var passives: PassiveTreeV2.State = null  # region passives_v2` (created on demand, like `perks`).
- `PassiveSystem.mod(c, stat)` → `tree.mod(c.passives, stat)`; `rule(c, x)` → `tree.has_rule(c.passives, x)`;
  both 0 / false when the inmate has no state (one dictionary lookup when cached).
- Bus (`autoload/event_bus.gd`): `passive_allocated(colonist_id, passive_id)`, `passive_removed(colonist_id,
  passive_id)` (undo / respec), `passive_marks_changed(colonist_id, free)`, `passive_deed(colonist_id, deed_id)`.
- Listeners → module calls: `skill_leveled` → `on_skill_level`; spawn (`ColonistSystem.spawn`) → `set_baseline`
  per skill at join level; `record_changed` → `check_records`; `debt_paid` → `bump_counter("installments")`
  (+ `"debt_cleared"` when `DebtState.remaining() == 0`); `colonist_rescued` → carrier `"rescues"`;
  `colonist_tended` → doctor `"tends"`; `day_started` → `"quiet_days"` +1 for every inmate (reset to 0 on
  `mood_break_started`); `batch_refined` → operator `"batches"` +1 (Overclock's burn counter).
- Side effects on allocate / remove (the module never touches other systems): `rule_no_armor` → unequip every
  non-weapon slot (`equipment.unequip`); `rule_always_informant` → `blocks._pick_informant()` re-run; any
  keystone → `combat.resum(c)` + `equipment._resum(c.id)` (cached stat blocks).
- Commands on `Simulation` (replay-safe): `allocate_passive(cid, id) -> bool`, `undo_passive(cid, id)`,
  `respec_passives(cid)` (pays `respec_cost` with `items.consume_stored` + `blocks._change(block, -standing)`,
  then `tree.respec(st, tick, TICKS_PER_DAY)`), `grant_passive_marks(cid, n, reason)` for quest verbs.
- Quest verbs (`sim/quests/*`): `passive_mark {who, n}`, `passive_deed {who, id}`.
- Save: `state_parts()` → `[cid, st.to_dict()]` per inmate; `state_hash` includes `tree.state_hash(st)`.
- NG+: `Legacy.ng_snapshot` adds `dossier.passives = tree.dossier_carry(st)` for the dossier inmate;
  `start_opts` → `apply_dossier`.
- `DebtSystem.credit(c, n)` (new, 6 lines): books `n` units as paid without consuming items (Quota Hawk, Blood
  Debt); emits `debt_paid` when it clears the debt.
- `tools/skill_model.gd`: print marks by day 10/25/45/60 (earning.md budget) for 3 seeds.

## W2 — numeric hook lines (each `# region passives_v2`, one line, next to the perks/traits read)
`P(c, s)` = `sim.passives.mod(c, s)` (0.0 when off → byte-identical goldens with the flag off: run
`--filter=test_golden` after every hook). Unchanged from r1 except the two new stats marked NEW.
| stat | file:line | today | with passives |
|---|---|---|---|
| mining_speed / ore_yield | sim/jobs/mine_job.gd:27,39,54 | perks | `+ P` |
| work_speed | sim/jobs/job_system.gd:190 | perks × traits shift | `+ P` inside the `1.0 +` |
| build_speed / build_cost / building_hp | build_job.gd:25, building_system.gd:427,437 | perks | `+ P` (building_hp may go negative: Jury Rig; clamp ≥ 0.2) |
| carry | trait_system.gd:47 `carry_cap` | traits | `+ P(c,"carry")` in the same multiplier |
| move_speed / hunger / rest_gain (NEW r1) | colonist.gd:62, needs_system.gd:29,38 | perks / traits | `+ P` |
| threat_attract | threat_system.gd:141 | perks | `+ P` (per colonist, floor 0) |
| target_weight **(NEW r2)** | threat_model.gd:496 `pick` colonist score | — | `× max(0.05, 1 + P)` — the same line traits v3 `target_weight_mult` will use; sum both when v3 lands |
| operate_speed / craft_speed / repair_speed | operate_job.gd:28, repair_job.gd:30,55 | perks / — | `+ P` |
| machine_breakage | building_system.gd:193 | traits | `× max(0, 1 + P)` (Jury Rig -1.0 → 0: never breaks) |
| waste_mult / contamination_per_batch | building_system.gd:174, contamination_system.gd:28 | perks, cap -0.4 | cap on the **sum** of perks + passives, unless `rule(uncapped_contamination_per_batch)`; the batch itself is clamped at 0 (never negative) |
| mutation_risk | mutation_system.gd:429 | traits | `× max(0, 1 + P)` |
| craft_input / craft_quality / quality_tier | building_system.gd:153, quality_system.gd:57,63 | perks / traits | `+ P`; tier shift applied before the `quality_cap_common` clamp |
| gear_wear / ammo_use | equipment_system.gd:253,270, ammo.gd:83 | — / perks | `loss *= max(0, 1 + P)` (only when `wear_enabled`); `+ P` |
| hit_chance / unarmed_hit / melee_damage / unarmed_damage / crit_chance / attack_speed | combat_system.gd:30,34,177,179,180,168 | perks / traits | `+ P`; crit: rng drawn only when the total > 0 (PW4 rule) |
| dodge_chance / damage_taken / armor_flat | threat_system.gd:649,1081, health_system.gd:28, combat_system.gd:106,111 | perks / traits | `+ P` (damage_taken cap -0.5 on the sum; armor folded into the cached block) |
| flee_threshold | job_system.gd:35 | traits | `traits.mod + P > -1.0` |
| bleed_rate **(NEW r2)** | health_system.gd:178 | `h.bleed_rate()` | `rate *= 1 + P(c,"bleed_rate")` |
| tend_quality / heal_speed / infection_chance | health_system.gd:71,78,79,185,208 | perks | `+ P` (doctor at 71–79, patient at 185/208; infection floor 0) |
| mood_base / break_chance / thought_injured | mood_system.gd:54,92,40 | traits | `+ P` |
| despair_mult / installment_pct / standing_gain | debt_system.gd:155, trait_system.gd:87, block_system.gd:73 | traits | `+ P` (installment cap -0.4; standing_gain -1.0 → 0 gain) |
| suspicion_gain / stash_cap / sale_price | contraband.gd:194,212 / :50 / :201 | cfg | `× max(0, 1 + P(seller))`; `+ roundi(sum P over inmates)`; `+= scaled(n, 1 + P)` |
| xp_mult_* / xp_mult_all | progression_system.gd:30 | `traits.xp_mult` | `× sim.passives.xp_mult(c, skill)` (floor 0: Chaplain learns nothing) |
Everything above is additive on an existing `1.0 + ...` so the flag-off value 0.0 is exact (no float drift).

## W3 — rule guards (`sim.passives.rule(c, "<x>")`, one `if` per line; `# region passives_v2`)
| rule | keystone | file:line | hook |
|---|---|---|---|
| unlimited_carry | Beast of Burden | jobs/haul_job.gd:61, deliver_job.gd:32 | NEW: `cap = 1 << 30` when rule |
| no_armor | Beast of Burden | equipment/equipment_system.gd:53 `equip` | NEW guard (slot != weapon → false) + unequip on allocate (W1) |
| mining_only | Mole | jobs/job_system.gd:190 `work_tick` | NEW: `generic *= 0.4` when work_type != mining |
| uncapped_contamination_per_batch | Slow Hands | contamination/contamination_system.gd:28 | NEW: skip the -0.4 floor (module `mod()` already skips its own cap) |
| refine_strike | Slow Hands | jobs/givers/operate_giver.gd:13 `find` | NEW: skip refineries while `contamination.fraction() > 0.5` |
| no_medicine | Essence Lung | health/health_system.gd:65 `tend` | NEW: return 0 for the patient |
| essence_heal | Essence Lung | health/health_system.gd:176 `_bleed_and_heal` | NEW: `mult *= 3.0 if mutation.is_tainted(c.cell) else 0.0` |
| taint_immune | Essence Lung, Tailings Eater | mutation/mutation_system.gd:417 `_expose_colonists` | NEW guard (continue) |
| quality_cap_common | Jury Rig | quality/quality_system.gd:63 `quality_shift` | NEW clamp to tier 0 after shifts |
| craft_only | Signature Work | jobs/job_system.gd:165 `assign` (via `work_order`) | NEW: keep only work types whose skill is crafting |
| no_downed | Dead Man Walking | health/health_system.gd:254 `_refresh` | NEW: `kill(c)` where `downed = true` would be set |
| rage | Short Fuse | combat/combat_system.gd:177 | NEW: `dmg *= rage_mult(mood.mood_of(c))` = `1 + 0.01 × clamp(50 - mood, 0, 50)`, or 0.75 when mood > 50 |
| field_tend | Field Surgeon | health/health_system.gd:183 `rest_mult` | NEW: `Injury.tended_by` (int) set in `tend`; bed mult when the tender has the rule |
| no_draft | Field Surgeon, Stretcher Bearer | combat/combat_system.gd:211 `set_drafted`, squads/militia.gd:116 | NEW guards |
| no_sleep | White Nights | needs/needs_system.gd:30 (decay), :98 (request) | NEW guards (rest pinned at 1.0) |
| night_breaks | White Nights | mood/mood_system.gd:60 (`add_thought(c, "night_terrors")` while `clock.is_night()`), :85 `_roll_break` chance ×3 at night | NEW branch; new `mood.json` thought `night_terrors` -15, until next day |
| no_installment | Trustee | colonists/trait_system.gd:87 `installment` (read by debt_system:64,146) | NEW: return 0 → never overdue, interest still rolls |
| always_informant | Trustee | society/block_system.gd:166 `_pick_informant` | NEW: pick him if alive (before the weighted roll; keeps the rng draw count) |
| off_roll | Ghost on the Roll | debt/debt_system.gd:69 `pay` (false), :139 `_daily` (return), contraband.gd:194 (no suspicion when seller has it), :236 `_confiscate` (skip his stash) | NEW guards (4 lines); `d_debt_cleared` unreachable by design |
| no_refinery | Clean Hands | jobs/givers/operate_giver.gd:13 | NEW: skip buildings whose recipe is a refining recipe |
| taint_mining | Tailings Eater | jobs/mine_job.gd:39,54 (`× 2` when `mutation.is_tainted(target)`) + `contamination.add(ore / 50.0)` | NEW branch; `ContaminationSystem.add(units)` exists for events |
| essence_craft | Essence Smith | buildings/building_system.gd:153 (inputs: +1 essence_ore, craft refused without it), :195 (`contamination.add(0.25 × per_batch)`) | NEW branch |
| burns | Overclock | buildings/building_system.gd:195 `batch_refined` → `passives.bump("batches")`; every 10th → `health.apply_damage(c, 0.1 × max_hp, "", "burn")` | NEW branch; `health.json` kind `burn` (no bleed, infectable) |
| double_armor | Armourer's Pride | equipment/equipment_system.gd:152 `_resum` | NEW: non-weapon totals ×2 |
| melee_only | Armourer's Pride | equipment/equipment_system.gd:53 (`equip` refuses ranged bases), progression:30 (shooting XP 0) | NEW guards |
| no_ammo | Full Auto | combat/ammo.gd:83 | NEW: `use = 0` |
| ignore_pain | Walking Wounded | health_system.gd:145 `can_act` (true), mood_system.gd:71 (no injured thought), combat_system.gd:205 `is_low_hp` (false), job_system.gd:35 (never flees) | NEW guards (4 lines) |
| medic | Stretcher Bearer | jobs/job_system.gd:35 (skip the flee override; rescue/tend givers stay open during alarm for him), rescue_job.gd:17 (carried patient: `bleed_rate` 0) | NEW branch |
| pacifist | Stretcher Bearer | combat/combat_system.gd:157 `_try_attack` (false), :211 `set_drafted` (false) | NEW guards |
| block_chaplain | Chaplain | society/block_system.gd:59 `despair_mult` | NEW: `× 0.5` if the block has a living chaplain not in a break; scanned once per day in `tick()` and cached per block |
| despair_frozen | Chaplain | debt/debt_system.gd:156 | existing tag check: `has_tag(c, "despair_frozen") or rule(c, "despair_frozen")` |
| debt_in_hp | Blood Debt | debt/debt_system.gd:146 `_daily` | NEW: on due day `credit(c, inst)` + `health.apply_damage(c, 0.2 × max_hp, "torso", "letting")`; skipped (missed) when downed |
| ore_installment | Quota Hawk | jobs/mine_job.gd:39,54 → `debt.credit(c, ore / 10)` (remainder carried in `State.counters.ore_credit`) | NEW branch |
| no_haul | Quota Hawk | jobs/givers/haul_giver.gd, deliver_materials_giver.gd `find` | NEW guards |
| ore_skim | Pocket Vein | jobs/mine_job.gd:39,54 → `contraband.stash[c.id] += ore / 10` (respects `skim_budget`) | NEW branch |
| raid_first | Pocket Vein | society/contraband.gd:236 `_confiscate` | NEW ordering: holders with the rule first, then `_top_holder` order |
Consumers that cache (`armor_flat` in the combat stat block, `totals` in equipment, the chaplain flag per block)
invalidate on `passive_allocated` / `passive_removed` — `combat_system.resum(c)` already exists for traits.
Determinism: no guard adds an rng draw; `always_informant` short-circuits *before* the roll but still consumes the
same draw (`rng.randf()` called and discarded) so seeds stay comparable with the flag on.

## W4 — UI, bot, ship checks
- `view/panels/passive_board.gd` (new, touch-first): header (inmate, marks free, keystones 2/2 with the two
  keystone icons), 6 detail chips, one card (3×6 grid of 64 px buttons, icon = `assets/sprites/passive_<id>.png`,
  frame alpha by state, struck diamond when `excluded`), seam half-diamonds for the four bridge keystones, bottom
  sheet on tap: name, desc, **Rule / Drawback lines for keystones** (data `rule`, `drawback`), effect lines,
  "Requires …" from the reason code, button Allocate / Undo (grace timer) / Respec (cost line). Opened from the
  colonist sheet ("Record" button, NEW badge when `marks_free > 0`), like the perk panel.
- Colonist sheet: rule flags render as one short line each (`rule_consumers[x].rule`), e.g. "Never sleeps".
- Letters: deed ≥ 2 marks → `letter_received`; milestones already post letters (add "+n marks"); a keystone
  allocation posts the Warden's one-liner ("Inmate 4 is logged as Beast of Burden. Armour returned to stores.").
- Bot (`tests/qa_bot.gd`): knob `passive_pick` = "first allocatable on the card of the best skill"; keystone when
  allowed, preferring the school whose notables it already holds. Balance from a table: extend
  `tools/balance_report.gd` with "marks spent / keystones / rules" and `tools/combat_model.gd` with Dead Man
  Walking, Short Fuse (mood 20 / 50 / 80), Armourer's Pride and Full Auto rows before tuning.
- Ship: `tools/web_smoke.py` taps the Record button; `tests/test_phone_layout.gd` gets the board at 844×390 DPR3
  (card + header + seam strip, no vertical scroll); goldens regen only after the flag is turned on (intended
  change, list the changed ticks in the report).
- Perf: `mod()` / `rules()` are cached per state and cleared on change; hook lines read them in hot loops exactly
  like `perks.mod` (one dictionary lookup when cached, 0 / false when the inmate has no state). No per-tick work
  in the system except the daily chaplain scan.

## Rollback
Flag back to false → every hook adds 0.0, every guard is false, the board button hides, saves keep the
`passives` part (ignored).
