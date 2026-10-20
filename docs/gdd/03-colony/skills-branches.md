# Skills, XP, perks, branches

## Skills `[BUILT]` — `sim/colonists/skills.gd`, `sim/progression/progression_system.gd`, `data/skills.json`, `data/xp.json`
8 skills: mining, construction, crafting, shooting, melee, medicine, plants, operating. Levels 0-10.
XP by use: 1 xp per work tick, attacks, patrol/training ticks, event awards (`xp.json`: day survived,
wave repelled, rescue, first refine, event choice). Passions x1 / x1.5 / x2 (minor 25 %, major 10 %).
Single level-up path `ProgressionSystem.award` emits `skill_leveled`.

| L->L+1 | 0->1 | 1->2 | 2->3 | 3->4 | 4->5 | 5->6 | 6->7 | 7->8 | 8->9 | 9->10 | total |
|---|---|---|---|---|---|---|---|---|---|---|---|
| xp | 100 | 160 | 250 | 400 | 650 | 1000 | 1600 | 2500 | 4000 | 6500 | 17 160 |

| level | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| efficiency | 0.30 | 0.60 | 0.80 | 1.00 | 1.10 | 1.22 | 1.36 | 1.52 | 1.70 | 1.90 | 2.20 |
`speed_mult = efficiency[L] x (1 + trait work_speed) x perk mods`; the same curve feeds hit chance and
craft quality. Spawn range `init.level_min 1 / level_max 4` (owner question 7: L0 start was rejected by
the bot). Milestones 3 / 6 / 10 post a letter (`data/meta.json milestones`), mood thought `leveled_up`,
1 legacy point (`per_milestone`). `tools/skill_model.gd` prints days to L3/L6/L10.
Note: the night-sprint skill curve (L0 = 0.3x) was the likeliest cause of the survival drop
(alive 9->7/10); kept, balance pass postponed by the owner.

## Perks `[BUILT]` — `sim/perks/`, `data/perks.json`, `view/panels/perk_panel.gd`
80 perks, 5 tiers per skill (one per 2 levels, `levels_per_point` 2), 2 mutually exclusive per tier;
points = skill level / 2 minus perks bought; respec for refined essence; active perks manual (`use_perk`,
e.g. `aimed_shot`). Total waste/contamination reduction from perks capped at 40 % (D23).
Perk mods affecting combat are folded into the cached att/def stat block (no loops in the hit path).

## Specialisation branches `[BUILT]` — `data/skills.json branches`, `choose_branch`, `branch_level` 5
At level **5** (old doc said 6; code and owner-review decision say 5) a skill picks one branch:
| skill | branch A | branch B |
|---|---|---|
| shooting | Marksman: +12 % hit, +10 % crit | Gunner: +1 shot per burst |
| melee | Warrior: +20 % weapon melee damage | Monk: +60 % unarmed damage |
| plants | Forester: sow/harvest 25 % faster | Farmer: yield +25 % |
| crafting | Smith: better craft quality | Tinkerer: 10 % less input |
| mining | Prospector: ore yield +25 % | Digger: mining 25 % faster |
All 11 effects are consumed (F3d tests). Not built: `operating` branches (Refiner / Filter-tech) `[IDEA]`,
Monk "calm: despair x0.7" `[IDEA]`. Bot knob `branch_pick` (first listed).

## Quality `[BUILT]` — `sim/quality/`, `data/quality.json`
Crafted gear gets a quality tier (5 levels) from the crafting skill + bench bonus + noise; gear ilvl for
crafted items is `equipment.json sources.craft_ilvl` 3.
