# Scout: research, expeditions, ecology, labor, debt, endgame
Sources from design knowledge of the named games (no live lookup). Format: Source | Our version | Why | Cost | Batch.
Pillars: mining safe / refining dangerous; essence debt; hand -> automation; creatures react to waste.

## Research / tiers
1. **Milestone part sets** - Satisfactory: HUB milestones demand delivered part counts per tier.
   OURS: "Audit Deliveries": the warden-AI (the prison system) accepts parts as proof of labor; each tier needs a set
   (e.g. 40 plates + 10 gears) shipped to a Delivery Hatch. Delivered parts are consumed, so research competes with building.
   Every tier also raises waste ceiling (R2 waste_mult). Fit: ties hand phase to unlocks. S-M. R2.
2. **Essence-priced breakthroughs** - Against the Storm / Frostpunk 2 (big irreversible choices).
   OURS: major techs cost essence = debt payoff diverted. Paying for a tech visibly delays release date (debt clock).
   Choice, not grind. Fit: essence is the meta-currency. S. R2.
3. **Research by failure** - Factorio science packs / Dwarf Fortress-like "learn by doing".
   OURS: "Tainted insight": first time a recipe produces waste above a threshold grants bonus research progress
   toward refining-adjacent techs (filters, scrubbers). Danger funds knowledge; safe play is slower. Fit: pillar 1. S. R2/R3.
4. **Bench time -> chip time** - Factorio labs / RimWorld research bench.
   OURS: bench work is a colonist job; AI Chip (late tech) installed in a bench runs it unattended but draws
   "attention" (see 9). Same data, different worker. Fit: labor automation. M. R2 then R5.

## Expeditions / inter-map logistics
5. **Element-locked outposts** - Factorio Space Age: each planet makes what others cannot.
   OURS: each biome yields 1-2 elements; a part (e.g. coil) is only craftable at a "forge site" with the right element.
   Map 2 = real map (decision). Home needs the part, so supply route matters. Fit: decided roadmap. L. R4.
6. **Cargo drops with a manifest** - Space Age rocket platforms / Mindustry launch pads.
   OURS: "Sling cargo": a capped-capacity launcher (ticks per shot) sends a crate home; crate lands at random spot
   near HQ within radius, may break if pile is overloaded. Not a belt: discrete, deterministic by sim.rng. M. R4.
7. **Expedition as debt-bearing crew** - Against the Storm villager caravans / board game "Pandemic Legacy" attrition.
   OURS: squad of prisoners leaves; each carries part of their debt as collateral. Death on map 2 adds to the
   colony debt, return trip cost in essence. Home stays running and creatures keep reacting without them. M. R4.
8. **Remote map autopilot** - Dyson Sphere Program: planets run unattended once built.
   OURS: unattended map 2 ticks coarsely (batch every N ticks, same rules, deterministic); events roll
   "outpost hit" reports. Keeps cost low and gives return reports. L. R4.

## Creature ecology vs industry
9. **Attention meter** - Dwarf Fortress / Frostpunk "tension" (not a Factorio copy).
   OURS: each machine emits Noise+Waste; creatures target the highest-attention structure, not the nearest.
   A decoy "Noisemaker" (cheap) pulls waves off belts. Fit: creatures damage belts/machines (decision). M. R3.
10. **Dirty ground ecology** - Factorio biters expand on pollution + ONI germs.
    OURS: contamination changes which species spawn: clean soil -> scavengers that eat rubble/scrap (useful),
    dirty -> mutated raiders; scrubbing land reverts it slowly. Creatures become both threat and tool. L. R3.
11. **Repair vs. rebuild bots** - Factorio construction robots.
    OURS: "Wardens' crew" automate repair, but each repair job burns an essence trickle -> automation has running debt. M. R3/R5.

## Labor / social / debt
12. **Debt ledger as a social system** - RimWorld mood/relationships + Papers Please.
    OURS: each prisoner has personal debt and a "lease" term; paying it off (essence tithe) frees them, which loses
    a worker but grants an ally/vote. Free ex-prisoners can be hired as paid specialists (wage in essence). M. R5.
13. **Overseer favors** - Frostpunk laws/promises.
    OURS: choose a rule ("Quota Law": +30% output, +waste; "Quiet Law": -waste, -output). Rules are in data/rules.json
    already; make them time-locked contracts with penalty if broken. S. R2/R3.

## Pollution consequences and endgame
14. **Local contamination memory** - ONI germs / Timberborn badtide.
    OURS: heavy-contaminated tiles stay "scarred" per region and permanently cost yield on those nodes unless cleaned;
    plays long-term: where you refine becomes sacrifice zone. Choice: dump zone. M. R3.
15. **Containment disposal** - Mindustry slag/scrap disposal + Shapez 2 overflow.
    OURS: waste can be buried (storage, finite), burned (smoke -> region contamination), or converted to
    "slurry" sold as essence at bad rate. Each choice is a different pillar-2 trade. M. R3.
16. **Release ending** - Frostpunk/Against the Storm "queen's favor" meter + roguelike run structure.
    OURS: goal = pay total debt and launch a Release Shuttle; shuttle needs top-tier part set + large essence.
    Alt ending: stay and take over the prison (warden AI fights). Run score from debt left, waste, deaths. M. R5.
17. **Seeded run modifiers** - Hades heat / Slay the Spire ascension / Against the Storm.
    OURS: after win, "Longer Sentence" levels (more debt, tougher waves, less safe ore). Needs deterministic seeds; free replay value. S. R5.
18. **Prisoner roster draft** - Darkest Dungeon / XCOM recruits.
    OURS: new prisoners arrive in transports with skill/trait/debt; you pick 1 of 3 (visible cost). S. R5.

## Priority guess for designer
Top: 1, 9, 5, 14, 12, 16. Quick wins (S): 2, 3, 13, 17, 18.
Risks: 5/8 multiply map count and test load; 10 couples ecology to contamination (needs a clean sim contract, R1).
