# Scout: inmate society (cell blocks, snitches, contraband, favors)
Hooks that exist: traits.json (skill/work_speed only), DebtSystem (per-inmate debt, installment, despair ->
mood thoughts + breaks/riot), MoodSystem, QuestLog (Q1 Clerk, Q2 Pilgrims, Q3 Parole, Q10, Q11 veteran),
Warden PA, roles/squads, NG+ veteran + Dossier. Gap: inmates differ only by skills; no social layer.

## Sources (searched live; Steam/forum items are fan reports, treat as unverified)
- Prison Architect: Gangs (Paradox press release 2022-06-14): gangs recruit by matching prisoner attributes,
  "Boiling Point" meter for prison danger, corrupt guards = contraband route, informants (C.I.s) expose them,
  rehab program. Idea taken: a visible danger meter + an informant who exposes a hidden problem.
- Frostpunk (Wikipedia, wiki): Hope and Discontent are SEPARATE meters; laws trade one for the other and
  show both effects before signing. Idea: policies with two-sided price shown up front.
- Oxygen Not Included (wiki.gg Room): one bonus per room type, no stacking; stress from skill load.
  Idea: bonuses from rooms/buildings capped per type, not per copy.
- RimWorld/DF/Banished: not re-verified (memory). Avoided: per-colonist social graph, memory/relationship
  thoughts, faction reputation. We keep ONE colony-wide ledger instead.

## 1. Cell Block Standing ("Block Boss") - cost M
Inspiration: PA gangs + Frostpunk two meters. Colonists get a hidden `block` (Lifer / Clerk / Zealot /
Informant / Fresh Fish from the bible) at generation; each block holds a colony-wide Standing 0-100.
Standing rises when the colony pays the debt installment on time, falls when a block member dies or is
docked. Low Standing in a block: its members despair faster (reuses despair_per_day x block mult).
Hooks: DebtSystem._daily, MoodSystem thoughts, generator.gd, data/blocks.json (new). Twist: the "gang"
IS your debt class; the Warden invoices you for blocks that are quiet ("Cohesion fee").
Accept: bot 10 seeds/60 d, same seed + same commands = same hash; break/riot count differs <=15% from
baseline while per-block despair spread (max-min) > 0 in 8/10 seeds.

## 2. The Informant (snitch with a price) - cost M
Inspiration: PA informants. One Informant per run (bible #4). Each day he reports a random "offence"
(missed quota, idle, stash) to the Warden PA for ration cuts to himself. Player choices via QuestLog:
tolerate (Warden audit penalty +fee), feed him false info (costs a Clerk's time), or "transfer" him
(removes a worker, ends reports). Twist: reports are the Warden's data on you - they ARE the "cleaner
colonies get delayed petitions" mechanism made visible.
Hooks: QuestLog (new data quest), Warden PA lines, petition_fee_mult mod. Accept: in 10 seeds the quest fires
>=7/10 and petition_fee_mult averages > 1.0 while informant alive, == 1.0 after resolve.

## 3. Contraband Stash (essence skim) - cost S/M
Inspiration: PA contraband + shakedowns. Inmates with high despair skim refined essence into a hidden
stash (a small "lost" counter from ItemSystem). Search action (Squad "shakedown" ability, costs a patrol
day) recovers it and spikes despair; ignoring it leaks essence to a black-market event that can cut one
installment by 1 unit (never beyond the 2% debt cap) but invites a mimic wave. Twist: the Company sold the
essence forward, so skimming raises contamination-linked threat. Hooks: DebtState.despair, squads/abilities,
ItemSystem lost. Accept: skim volume <= 3% of refined output per seed; shakedown count > 0 in 8/10 seeds.

## 4. Two-meter Policy Sheet ("Standing Orders") - cost M
Inspiration: Frostpunk laws, reduced to 4 data entries. Rules in rules.json already exist; add a sheet with
Hope (calms despair) and Compliance (Warden audit score). e.g. "Double shifts": +work, +despair;
"Roll call": -despair, -work 5%; "Report all": +Warden score, Informant gets stronger. Each shows both
numbers before confirm. Hooks: Simulation.set_rule, DebtSystem cfg, Hud sheet. Accept: a bot that picks
each policy for 20 d shows measurable shift in production and despair in the shown direction (model table).

## 5. Veteran Network (NG+) - cost S
Inspiration: DF legends / roguelike meta. A carried veteran (Dossier perk) brings 1 known contact: one
block starts at Standing 60 and one quest hint is pre-revealed. Previous-run history lines
("Previous Tenant" Q11) name the veteran's old block. Hooks: meta_state, ng_flavor.gd, Q11. Accept: run 2
despair spread in that block is lower at d25 in >= 7/10 seed pairs.

## Order
1 (foundation, data only) -> 2 -> 4; 3 after squads settle; 5 last. All text English, tuned from a table
(like tools/combat_model.gd). Do NOT add per-pair relationships.
