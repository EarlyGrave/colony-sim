# Progression & Traits — design (Fable lead, 2026-10-19)
Source: owner notes 2026-10-19 (numbers = direction only). Current state: `Skills` (levels 0-10, linear XP
`100+40L`, speed `1+0.1L`, passions), `data/traits.json` (7 traits, skill init + work_speed only, rolled flat
50% x2 in `generator.gd`), perks (5 tiers, 2 excl. per tier), `ProgressionSystem.award()` + 5 other raw
`add_xp` emit sites, NG+ dossier `{name, skills, perk_id}`, blocks (`sim.blocks.despair_mult`), DebtSystem despair.

## 1. Skill levels: XP table and efficiency curve (data/skills.json)
Growth stays use-driven: work ticks (jobs, workbenches, tools), attacks and patrol/training-range ticks
(`patrol_job`), event awards (`xp.json`). Passion multipliers stay (1 / 1.5 / 2).

| L→L+1 | 0→1 | 1→2 | 2→3 | 3→4 | 4→5 | 5→6 | 6→7 | 7→8 | 8→9 | 9→10 | total |
|---|---|---|---|---|---|---|---|---|---|---|---|
| xp | 100 | 160 | 250 | 400 | 650 | 1000 | 1600 | 2500 | 4000 | 6500 | 17 160 |
Ratio ~1.6 per level; 0→3 costs 510 (a few days of work), 9→10 alone costs more than 0→6 (owner: "10 is
a huge effort"). Work tick = 1 xp, so a full-time L9 miner needs ~6500 ticks on top of ~10 600 before.

| level | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| efficiency | 0.30 | 0.60 | 0.80 | 1.00 | 1.10 | 1.22 | 1.36 | 1.52 | 1.70 | 1.90 | 2.20 |
Efficiency replaces `speed_per_level`: `speed_mult = efficiency[level] * (1 + trait work_speed) * perk mods`.
Same curve feeds combat: `hit_per_skill` becomes `hit = hit_base + hit_span * (efficiency[L] - 1.0)`;
crafting quality roll bonus = `efficiency[L] - 1.0` (quality.json already rolls per level: swap the input).
Because L0 = 30 %, spawn range moves to `level_min 1, level_max 4` and traits add on top (clamped 0..10).
```json
"xp_table": [100,160,250,400,650,1000,1600,2500,4000,6500],
"efficiency": [0.30,0.60,0.80,1.00,1.10,1.22,1.36,1.52,1.70,1.90,2.20],
"milestones": {"3": "journeyman", "6": "expert", "10": "master"},
"init": {"level_min": 1, "level_max": 4, "minor_chance": 0.25, "major_chance": 0.1}
```
Level-up as an event: every level-up emits `skill_leveled` (exists) from ONE place (`ProgressionSystem.award`;
the 5 raw `add_xp` callers switch to it). Milestones 3/6/10 additionally post a notification letter
("Varga is now a journeyman miner") + mood thought `leveled_up` (+4, 1 d; master +8, 2 d) and award
`legacy.per_milestone` 1 pt. Non-milestone level-ups only ping the log line (phone: no spam).

## 2. Specialisation branches (design now, build in a later batch)
At level 6 a skill picks ONE branch (player choice via the perk sheet; bot: first listed). Branch = tag on
tier 4-5 perks (`"branch": "marksman"`), so the existing perk tree is reused: tiers 1-3 shared, tiers 4-5
gated by branch. Planned: shooting → Marksman (range, aimed) / Gunner (volley, suppress); melee → Warrior
(damage, armor) / Monk (dodge, unarmed, calm: despair x0.7); plants → Forester (wood/fibre, ecology regrowth)
/ Farmer (yield, double harvest); mining → Prospector / Blaster; operating → Refiner / Filter-tech (clean).
Data only: `skills.json: "branches": {"shooting": ["marksman","gunner"], ...}`; `Skills.branch: Dictionary`.

## 3. Traits (data/traits.json v2)
Innate physical/character features; affect peace-time (work, food, mood) AND stress-time (despair, breaks,
flee) behaviour. Never purely negative: every trait has a niche. Rolled at generation: weighted draw without
replacement (common 30 / uncommon 12 / rare 5), `max_traits 2`, 25 % chance of zero traits, `excludes`
honoured, `block_only` honoured (block is assigned before the draw: move `blocks.block_of(c)` up).
Effects are read ONLY via `sim.traits.mod(c, stat)` (summed additive, like perks) / `has_tag(c, tag)`.
```json
{"schema": 2, "rarity_weight": {"common": 30, "uncommon": 12, "rare": 5}, "max_traits": 2, "none_chance": 0.25,
 "acquired_max": 1,
 "traits": {
  "strong": {"name": "Strong", "desc": "Built like a bulkhead door.", "rarity": "common", "excludes": ["frail"],
    "skills": {"mining": 2}, "effects": {"carry": 0.25}, "role_affinity": {"bulwark": 1}},
  "cold_blood": {"name": "Cold Blood", "desc": "Does not run. Ever.", "rarity": "rare", "excludes": ["jittery"],
    "effects": {"flee_threshold": -1.0, "break_chance": -0.5, "xp_mult_medicine": -0.2}},
  "hardened": {"name": "Hardened", "acquired": true, "trigger": "rescued", "rarity": "rare",
    "effects": {"thought_injured": 0.5, "flee_threshold": -0.3}}}}
```
Stats consumed (each one line at an existing hook): `work_speed` (job_system), `carry` (haul amount),
`hunger` (needs), `mood_base` (mood _recalc), `break_chance` (mood _roll_break), `despair_mult` (debt _daily,
next to the block mult), `flee_threshold` (jobs flee override), `hit` (combat), `xp_mult_<skill>` (award),
`standing_gain` (blocks), `mutation_risk` (mutation), `thought_<id>` (mood add_thought scale).

### Example traits (name — niche; effects in direction units)
1. **Strong** (common) — mining +2, carry +25 %. Excl. Frail.
2. **Frail** (uncommon) — hunger −20 %, work −8 %, xp crafting/medicine +15 %. Niche: famine runs.
3. **Handy** (common) — construction +2, crafting +2.
4. **Careful** (common) — medicine +2, machine breakage −30 %, work −5 %. Excl. Hasty.
5. **Hasty** (common) — work +10 %, hit −8 %, quality −1 tier. Niche: haulers, rush builds.
6. **Slow Burner** (common, was Lazy) — work −10 %, mood_base +6, despair x0.8. Niche: never riots.
7. **Green Thumb** (common) — plants +3, xp plants +20 %.
8. **Iron Stomach** (uncommon) — raw food / spoiled thoughts ignored, hunger +10 %. Excl. Delicate.
9. **Delicate** (uncommon) — ate_raw thought x2, medicine +1, xp all +10 % (learns by complaining).
10. **Night Owl** (uncommon) — work +15 % at night, −10 % by day. Excl. Early Bird.
11. **Early Bird** (uncommon) — mirror of Night Owl.
12. **Cold Blood** (rare) — never flees, break chance −50 %, xp medicine −20 %. Excl. Jittery.
13. **Jittery** (common) — flees early (+0.3), move +15 %, xp shooting +30 % on the range. Niche: survives.
14. **Done Time** (uncommon, `block_only: lifer`) — despair x0.7, xp all −10 %. Excl. Quick Study.
15. **Quick Study** (rare) — xp all +25 %, mood_base −3 (restless).
16. **Essence Nose** (rare) — refining +10 %, no taint thoughts, mutation risk +20 %. Pillar tie-in.
17. **Thick Hide** (uncommon) — flat armor +1, hunger +10 %.
18. **Loud Mouth** (uncommon) — block standing gain +50 %, own break chance +20 %. Niche: block politics.
19. **Ledger Eye** (rare, `block_only: clerk`) — installment −5 % (negotiates), work −5 %. Debt tie-in.
20. **Scrapper** (common) — melee +2, unarmed hit +10 %.
Acquired (decided without owner, review; max 1 per inmate, deterministic triggers, never rolled at birth):
**Hardened** (downed then rescued: injured thought x0.5, flee −0.3), **Resigned** (despair ≥ 80 for 5 days:
despair stops growing, work −15 %, mood_base +4), **Settled** (30 days without a break: mood_base +5,
leaves if the colonist breaks). Emergence stays a "scar" layer, not RimWorld children.

## 4. Ties
Debt/despair: `despair_mult`, Resigned, Ledger Eye, Done Time read/write `DebtState.despair` through the
existing `_daily` multiplier chain (blocks x quests x traits). Blocks: `block_only` traits + Loud Mouth.
NG+ veterans: dossier gains `"traits": [innate ids + acquired]`; `start_opts` re-applies them (acquired ones
carry over = the veteran's story), and `legacy.per_milestone` counts milestones reached. Perks keep their
tree; branches gate tiers 4-5 later. Determinism: all draws via `sim.rng`, fixed draw count per colonist
(rarity table iterated in file order).

## 5. Migration
1. `skills.json`: `xp_base/xp_step/speed_per_level` → `xp_table/efficiency`; `Skills.xp_needed/xp_total/
   speed_mult` read the arrays (fallback to old keys if absent for one batch). Goldens regen (intended).
2. `traits.json` v1 → v2: keep the 7 ids (rename `lazy` → `slow_burner` with alias), add `rarity`, `effects`,
   `excludes`; `work_speed` moves into `effects`; `c.bio.work_speed` stays as a cached number for the view.
3. All `add_xp` emit sites → `sim.progression.award(c, skill, amount, reason)` (single level-up path).
4. Save/meta: `dossier.traits` optional (old saves → `[]`).

## 6. Worker-ready breakdown (one wave, 3 workers, ~2.5 h, disjoint files)
**W1 Curve & XP** — owns `sim/colonists/skills.gd`, `data/skills.json`, `sim/progression/progression_system.gd`,
one-line swaps in `job_system.gd:193-196`, `combat_system.gd:20,65`, `patrol_job.gd`, `research_job.gd`,
`idle_work_system.gd` (`# region progression`), `tests/test_skills.gd`, goldens regen.
Accept: xp table/efficiency from JSON; L3 speed == 1.0, L0 == 0.3, L10 == 2.2; 0→10 total == 17 160;
`skill_leveled` emitted exactly once per level from `award`; same seed + commands → same hash; goldens regen'd
with changed ticks listed in the report.
**W2 Trait system** — owns new `sim/colonists/trait_system.gd` (`mod`, `has_tag`, `grant`, acquired triggers on
`colonist_rescued`/`day_started`), `data/traits.json` v2, `sim/colonists/generator.gd` (weighted draw, block
first), hook lines in mood/debt/needs/jobs flee (`# region traits`), `Simulation` registration, `tests/test_traits.gd`.
Accept: excluded pairs never co-occur over 500 generated inmates; rarity frequency within ±30 % of weights;
`block_only` respected; Hardened granted after rescue and never twice; Resigned stops despair growth;
determinism test; all 20 traits present with `desc`.
**W3 Events, NG+ & sheet** — owns `data/mood.json` (+`leveled_up` thoughts), `data/events.json`/notification
text for milestones, `sim/meta/meta_state.gd`, `sim/meta/start_opts.gd`, `sim/meta/ng_flavor.gd`, `data/meta.json`
(`per_milestone`), `view/` colonist sheet (efficiency %, trait name + desc, milestone badge), `tests/test_ng_meta.gd`,
`tests/test_ui_perks.gd` additions. Listens to `skill_leveled` only (no sim edits beyond meta).
Accept: milestone letter appears at L3/6/10 and not at others; veteran arrives in run 2 with dossier traits and
levels; phone screenshot of the sheet via `tools/screenshot.tscn`; web smoke green.
Order: W1 and W2 in parallel; W3 reads only bus signals so it merges last. Balance pass afterwards from a table
(`tools/skill_model.gd`: days to L3/L6/L10 for a full-time worker, 3 seeds), not by eye.
