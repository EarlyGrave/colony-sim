# Scout: the mid-game loop (days ~20-60) — 6 candidates, ranked
Problem (bot data): d20-60 colonies stall (petition P1-P4 slow, refined scarce: P4 short 60-76 refined) or die (waves).
Today the only mid-game decisions are "what to build next" and a few crisis popups. We need DIALS with a legible price,
not new systems. Already in repo and reused below: petitions.json, crises.json options, contracts, beacons, ecology nests
+ scent/dormancy, chips (upkeep), gear/craft_gear + quality tiers, traits/mood, rules.json `set_rule`, standing/audit.
Sources checked live 2026-10-20 (web search; community-level facts, formulas unverified): Against the Storm hostility/
resolve/orders (forum + HoodedHorse wiki), Frostpunk laws vs hope/discontent (wiki, PC Gamer), Dwarf Fortress strange moods
(wiki), ONI germs/pollution (wiki). Mindustry/Factorio-pollution-wave: no primary source found, treated as memory only.

## Ranking (value for stall+death / cost / risk)
### 1. Standing Orders — "Shift Regulations" (S-M, risk low)
- Inspiration: Frostpunk laws (mutually exclusive branches, each moves hope AND discontent) + Against the Storm orders.
- Ours: at d15/30/45 the Warden's office posts a Regulation form; pick ONE of 3, signed in debt. E.g. "Double Shift"
  (refining +25% speed, waste x1.3, mood -8, installment +10%); "Quiet Hours" (waste x0.7, speed -15%, creatures -20% at night);
  "Overwatch" (turrets +15% fire rate, -1 refiner slot). Earlier picks lock branches (Faith/Order style).
- Why: pillar 1 as an explicit dial ("faster refining = harder waves" becomes a choice, one number in the hint), pillar 2.
- Reuses: rules.json + `Simulation.set_rule`, crises option format (mods dict), mood, threat mults, debt installments.
- Bot: picks by knob; eval column `regs`. Risk: balance only; all data. New UI = one modal like crises (exists).
### 2. Petition alternatives — "Waivers" (S, risk low)
- Inspiration: Frostpunk "Emergency" laws / RimWorld quest reward choices; here a bureaucratic loophole.
- Ours: each petition phase offers a 2nd payment form: P1 plates 60 -> "Volunteer Detail": 3 inmates do N hours on a hazardous
  task (haul from a nest edge, clear a blocked drill) and take injury risk; P3 refined -> "Informant Report" (suspicion/standing
  hit, covert trade tie-in). Pay in people/risk instead of the scarce item.
- Why: attacks the exact stall (plates and refined are the wall) with a risk-for-resource trade. Debt/petition pillar.
- Reuses: petitions.json (`alt` block), jobs (hazard duty), standing, contraband suspicion. Risk: bot must handle choice.
### 3. Reclamation Scrubber — "Sludge Reprocessing" (M, risk medium)
- Inspiration: ONI (pollution is a resource to clean/convert) + Factorio recycling. Not a copy: output is DEBT, not water.
- Ours: Scrubber building eats raw waste (tainted cells within r) + power and emits `reclaimed_slag`; 5 slag -> 1 refined at
  a loss, or 3 slag -> -1% debt. Cleaning lowers local contamination so scent/hunger bank drops (waves soften).
- Why: gives a second answer to "refined scarce" without breaking "refining pollutes": you spend labour/power to undo it.
- Reuses: contamination cells, recipes (`pollutes` flag), power, haul, beacons-style debt cut. Risk: could trivialise pillar 1;
  gate behind research T3, cap throughput, check kx_pillar_table gap >= 2.0 before merge.
### 4. Fixation (strange mood) (S-M, risk low)
- Inspiration: Dwarf Fortress strange mood: an inmate seizes a workshop, demands items, makes an artifact or goes mad (wiki).
- Ours: a skilled inmate (L3+, trait-weighted) gets "Fixation": needs 6 plates + 2 refined + a bench within 3 days. Success: one
  masterwork gear piece (top quality tier, signed with their name -> epilogue/Q15 tie). Fail: breakdown + lose the items.
- Why: a plate/refined SINK that is a story choice (feed it or save for petition), colonist identity, ties to Roll Call lore.
- Reuses: traits, mood breaks, craft_gear, quality.json, Enemy.name_of_dead. Risk: bot ignores -> decline path needed (free).
### 5. Slag Heap decoy (M, risk medium-high)
- Inspiration: They Are Billions / Mindustry bait + Against the Storm "reduce hostility by choosing where".
- Ours: a cheap Slag Heap deliberately dumps waste in a kill zone; scent pulls wave origin and target there (turrets cluster).
  Price: it raises contamination and the hunger bank locally; heap is a raid objective that must be re-fed.
- Why: converts "waves kill me" into a layout puzzle; waste becomes a tool. Reuses scent, raid_objectives (OFF now!), ecology.
- Risk: raid_objectives is OFF (F1c: alive 7->5). Needs that fixed first -> defer.
### 6. Creature haze (fog_of_war.md option D) (M, risk low, value LOW for this question)
- Info-only in phase 1, goldens unchanged. It adds tension and a visible price of pollution ("Haze: sight -40%") and a reason for
  Watchtower/lamps, but it does not unstick petitions nor reduce deaths; bots cannot show its value. Rank 6 of 6 for the mid-game
  loop; keep as a later flavour/visibility batch (after #1-#4), flag OFF.

## Not picked (already covered or heavy)
Seasons/weather (ATS): storyteller events + forecast ticker cover it. Caravans/trade (Syx): out of scope. Research tree
rework: heavy. Hostility meter: our scent/dormancy is already the equivalent.

## Recommended batch "Mid-game dials" (one wave, disjoint files)
A. Standing Orders (#1): data/regulations.json, sim/storyteller region, modal in crises panel; bot knob + `regs` column.
B. Petition waivers (#2): data/petitions.json `alt`, hazard-detail job, small UI row in the petition panel; bot takes alt when stuck.
C. Fixation (#4): data/fixation.json, trait/mood hook, craft_gear masterwork output; decline = free.
D. (optional, M) Scrubber (#3) as its own worker with a pillar-table gate; if gap < 2.0 ship flag OFF.
Acceptance floor from next_batches.md (alive>=8 >=7/10 baseline, P1/P3 not lower); target: P3 >= 4 and refined at d40 +20% on
stalled seeds (1/6) with Waivers ON; Orders flag OFF by default until a bot table per option exists. Haze and Slag Heap later.
