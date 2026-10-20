# Traits v3 — integration plan (what wiring would take)

Today: flag off, zero behaviour change. The module is self-contained; integration is one batch of 3–4
workers with disjoint files. Estimated cost M (two waves if the view work is included).

## 0. Switch
`data/balance.json` `traits_v3_enabled: true` → Defs loads `traits_v3.json`; `Simulation` creates
`traits_v3 = TraitSystemV3.new(self)` next to `traits` (keep v2 alive until goldens are regenerated).
`ColonistGenerator.generate` calls `sim.traits_v3.apply_birth(c, rng, {block})` **instead of** `traits.roll`
(same rng, 6 draws instead of 3 → goldens change, `tools/make_golden.gd --regen` once).

## 1. Stat registry → consumer (exact file, one line each)
Existing v2 hooks: replace `sim.traits.X` with `sim.traits_v3.X` (same helper names) in:
`jobs/job_system.gd` (work_speed, shift_mult, flee_threshold), `jobs/haul_job.gd` + `deliver_job.gd`
(carry_cap), `needs/needs_system.gd` (hunger), `mood/mood_system.gd` (mood_base, thought mult →
`thought_mult`, break_chance), `debt/debt_system.gd` (despair_mult, installment, despair_frozen tag),
`combat/combat_system.gd` (hit, unarmed_hit, armor_flat), `progression/progression_system.gd` (xp_mult),
`society/block_system.gd` (standing_gain), `mutation/mutation_system.gd` (mutation_mult),
`buildings/building_system.gd` (refine_speed, breakage_mult), `quality/quality_system.gd` (quality_shift),
`colonists/colonist.gd` (move_bonus), `meta/start_opts.gd` (dossier re-apply), `quests/quest_log.gd` (verb).

New stats (`stats` in the JSON lists the consumer; summary):
| stat | file | hook |
|---|---|---|
| max_hp | colonists/generator.gd | done inside `apply_birth` |
| melee_damage | combat/combat_system.gd | damage roll × (1 + mod) for melee attacks |
| heal_rate / injury_severity / illness_severity | health/health_system.gd (`heal_mult`, `severity_mult`) | heal tick, add_injury, add_illness |
| rest_decay / rest_gain | needs/needs_system.gd | rest need |
| alarm_delay | jobs/job_system.gd | ticks before the flee override kicks in |
| suspicion_gain / defiance_gain | threats/metro_track.gd | per-inmate sales / defiant acts |
| contraband_price / contraband_find | society/contraband.gd | sale value, find roll |
| target_weight | threats/threat_system.gd `pick_target` | weight × `target_weight_mult` |
| spot_range / warning_ticks | idle_work patrol, threats wave_incoming | radius, earlier `wave_incoming` for the colony if any inmate has it (max) |
| informant_weight | society/block_system.gd informant pick | base weight + mod (clamped ≥ 0) |
| petition_weight | research/petition_system.gd | contribution × (1 + mod) |
| riot_spread | debt/debt_system.gd | chance a block mate joins a riot |
| scrub_speed / purify_cost / mining_speed / research_speed | the job or system named in the JSON | work multiplier / cost |
| fixation_chance | fixation/fixation_system.gd | offer roll |
| debt_total | debt/debt_system.gd | state creation (Charge only) |
| aura_* | mood/progression (see interactions.md) | `sim.traits_v3.aura(c, "mood", block_mates)` |
| leaning_* | society/block_system.gd | `leaning(c)` summed into the block vote |
| thought_neg / thought_pos | mood/mood_system.gd | inside `thought_mult` |
| tend_xp | health/health_system.gd tend | doctor xp × (1 + mod of the patient) |
| creature_essence | threats/threat_system.gd | extra essence on kill by this inmate |
| work_streak / work_switch | jobs/job_system.gd | `streak_mult(c, ticks_on_same_type)` |
| standing_effect | society/block_system.gd | -1.0 = this inmate ignores block thoughts/despair mult |

## 2. Event emitters (acquisition.md §3–5)
One worker: a small `TraitEvents` adapter (`sim/colonists/trait_events.gd`) that listens on the bus and
calls `sim.traits_v3.event(c, name)`; daily loop for `day_served`, `calm_day`, `despair_day`,
`high/low_standing_day`, `starving_day`, needs (`daily_needs` with a ctx built from JobSystem / Research /
Storyteller / BlockSystem / ItemSystem) and bonds (`try_bond` over block pairs in id order, one rng draw
each from a child rng seeded from `sim.rng`). Thoughts from `daily_needs` go through `MoodSystem.add_thought`.
New `mood.json` thoughts: `no_tunnel`, `nothing_new`, `no_letter`, `routine_broken`, `no_audience`,
`hum_fades` (values in interactions.md §1).

## 3. View (phone)
`view/panels/sections/colonist_section.gd`: replace the text trait list with a badge row of
`summary(c)` icons (`TextureRect` 32×32, tap → sheet with name/desc/effect/since-day). Arrival letter:
Charge first. Letters on `event()` results ("+id" → Warden line from a small table in `traits_v3.json`
`letters`, to add). Threat overlay: faint glow for `target_weight > 0`.

## 4. Migration from v2
Aliases v2 → v3 for dossiers/NG+ (`start_opts.gd`): strong→t_hulking, frail→t_wiry, handy→(skills only),
careful→t_methodical, hasty→t_reckless, slow_burner→t_stoic, green_thumb→t_charge_poaching, iron_stomach→
t_lean_years, delicate→t_bleeder, night_owl→t_insomniac, early_bird→(drop), cold_blood→t_dead_nerves,
jittery→t_paranoid, done_time→t_old_timer, quick_study→t_curious, essence_nose→t_charge_essence_theft,
thick_hide→t_second_skin, loud_mouth→t_agitator, ledger_eye→t_charge_fraud, scrapper→t_charge_murder,
hardened/resigned/settled → same names with `t_`. `data/roles.json affinity trait_weight` keys renamed.

## 5. Tests the integration batch must add
Goldens regenerated once; `test_traits_v3_live`: 500 newcomers have exactly one Charge; a refinery run
over 40 days produces ≥ 1 Glowtouched with `illness_chance` forced to 1.0; a block with Agitator riots more
than a control seed (bot numbers, `tools/balance_report.gd`); phone layout test with 5 badges.

## 6. Perf
`mod()` is a linear scan over ≤ 6 ids per call; same cost as v2. Auras need block membership lists
(BlockSystem already caches them). Needs/bonds are daily, O(n²) over block pairs (n ≤ 30) — fine at 250 inmates.
