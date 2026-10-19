# Economy & endings — quota, refining, parts, three (+1) endings, Next Sentence (2026-10-19, v2)
Author: game designer (Fable). Source of truth: docs/design/owner_notes_2026-10-19.md (numbers = direction only).
Master doc: docs/design/GDD.md. Baseline bot (factory_eval 10 seeds/60 d): launch 1/10, alive>=8 9/10, audit 8, P1 5, P3 3.

## Problems in the current economy (d25-d60 is a grind)
P1. One currency, seven sinks, no choice: refined essence pays installments, research, turrets, machine_parts, AI
    chips, Petition IV (60) and release parts (24). Every sink is "deliver N at the terminal"; the only decision is order.
P2. Debt is a tax, not a story: unpayable by design (8 x 120-280 vs ~400 refined/60 d), and the shuttle ignores it.
P3. The shuttle is a shopping list with one siege; nothing the player did (quota, pollution, people) changes the end.
P4. The pillar bites once: with clean smelting only refine_essence pollutes, so the late game (plates/parts/nitrogen)
    is a logistics puzzle (copper stuck in rock miners, one broken iron miner), not a dirty-vs-clean dilemma.
P5. Next Sentence changes numbers (25% debt, +1 preset, veteran), not the shape of the run.

## Mapping the owner's story onto what exists (what stays, what becomes what, what is cut)
| today | becomes | code |
|---|---|---|
| DebtSystem (per-inmate refined debt, installments, grace, despair, riot/escape) | **Quota**: the Metropolis norm, booked per lifer; installment = share of the next pickup; despair = fear of the quota shuttle leaving without their share. Mechanics unchanged, text and names change | keep; data/debt.json renamed keys only in UI strings |
| Contracts (Warden quotas) | **Side orders** from the jailers (same), later also **buyers** on the Escape path | keep; e2_dispatch tiers = buyers |
| Audits (tiers 2/3) | **Inspections**: same gating; on Escape they also roll suspicion | keep |
| Petitions I-IV | **Compliance Deal** (Submit path only): the jailers' offer after the truth; P4 = first endgame component | keep data, gate on path |
| Release shuttle + gantry + siege | **Extraction Platform** (Submit ending): quota shuttle lands only when endgame components are delivered; countdown siege = the planet's madness peak | keep system, rename, siege formula |
| Dispatch (e2, ship bundle to outer block) | **Covert sale channel** (Escape): several buyers, each pays credits and adds suspicion | keep, extend |
| Penance beacons (S2) | **Lowering suspicion / calming creatures** on Fight and Remission paths | keep as is, new effect reader |
| Expeditions / sling / outposts | **World-map point** for the bandit pickup; outposts = hidden stockpiles for Escape | keep |
| NG+ Next Sentence (carry debt, veteran, techs) | **New Names** (after Submit) and **New Sector** (after Escape); Fight ends in a free planet (Continue sandbox), no NG+ carry except legacy | keep, branch by ending |
| Shuttle "win_letter", Q4 Gantry Signal, Q5 Outpost 7 | cut / folded into the truth beat (Q-Truth) | cut |
Cut outright: nothing with code; only texts and the single-ending assumption. All pollution still comes from refine_essence (owner rule).

## The truth beat and the path (the spine; owned by society_narrative.md Q14 "Three Forms")
The revelation and the choice are Q14 (clues_held >= 2 + day 30): quest verb `path {id}` sets flag `path_<id>` with ids
submit | fight | escape (+ remission, E4). Economy systems read the flag through one helper `sim.path()` (new, in
ending_system.gd) so nobody greps flags. Reversible once via Q14b until a **point of no return** per path (below); the PoNR
sets `path_locked`. Before the truth every path is identical (quota, inspections, mining safe / refining dangerous).

## Endings
E1 Submit (bad). PoNR: accept the Compliance Deal (Petition I). Petitions I-IV = jailers' deal; P4 unlocks the Extraction
   Platform; deliver `seats` release parts (one per colonist aboard; `set_manifest` to leave people behind). Final waves =
   current countdown siege x `madness_mult` = 1 + pollution_frac (peak madness), plus 2 Metropolis drone-shuttles of goods
   pickup. Win screen: new names, planet destroyed, Next Sentence "New Names" (carry nothing but the Dossier; debt 0).
E2 Fight (good). PoNR: first ignored pickup after Q14. Quota shuttle leaves empty -> `defiance` climbs and the Metropolis
   track raids (threats_pacing.md 2b: `metro_track.gd`, `data/metro.json`, energy damage from combat_items.md; threats lead owns it).
   Refined essence is spent only on own needs (research, turrets, cells); pollution stays low so creature waves are mild
   while human raids grow — the pillar inverts on purpose. Endgame: build **Uplink Array** (tier 3, 60 parts, 20 fuel cells,
   30 power) and survive the **Collector assault** (3 raid tiers in 2 days); on win the Collector is destroyed:
   drops stop, raids stop, "free colony" sandbox (Continue). Legacy x2. No carry-over NG+.
E3 Escape (grey, economic). PoNR: contact the bandits (quest after 3 covert sales). Covert sales = e2_dispatch tiers
   turned into buyers: each sale pays `credits` (new ledger item, not droppable) and adds `suspicion` (0-100, new scalar
   in ContractSystem). Suspicion rises per sale (+8..15 by buyer), per Informant report (+5), per failed inspection;
   falls 2/day and -10 per audit passed. At 100 the jailers raid (Metropolis tier 3) and seize stock. Price of the pickup:
   `bandit_fee` credits (~2 full quotas); then the colonists walk to a world-map point (campaign sling target) with a
   countdown and a pursuit wave; legacy per colonist extracted. NG+ "New Sector" (carry credits 10%, veteran).
E4 Remission (proposed 4th, "stay"). The monsters were people: refined essence can be turned back. Recipe `cure`
   (refined 2 + bog_resin 1 -> cure 1, clean) fed to **Decontamination Pylons** (reuse beacon_launcher code) lowers
   contamination below `remission_frac` 0.1 for `remission_days` 15 while quota is still met (so the jailers never look).
   Creatures calm, late waves spawn "remitted" inmates who join (colonist source). Win: planet quiet, colony stays; the
   only ending that rewards refining less. Cost M, mostly data + one reader in ContaminationSystem.

## Concrete economy changes (all endings share them)
C1 Dirty fuel (S): `fuel_cell_dirty` essence_ore 6 + refined 1 -> fuel_cell 1 + waste 3, refinery, `pollutes: true`,
   unlocked by bulk_refining. Fast but wakes the planet; the clean nitrogen cell stays. Hooks: recipes.json, research.json.
C2 Siege/raid scale by path state (M): `strength_mult` arg on `ThreatSystem.start_wave`; Submit uses madness,
   Fight uses missed pickups, Escape uses suspicion. One formula place, data/endings.json.
C3 Manifest seats instead of parts (M): `parts_need` -> seats; unseated colonists stay (Continue colony). Submit/Escape.
C4 Launch window (S): after the PoNR a notice every 8 d raises wave_mult +0.1 (cap 1.5) until the ending resolves.
C5 Credits + suspicion (M): new `sim.ledger` currency `credits` and `ContractSystem.suspicion`; buyers in contracts.json.
C6 Next Sentence by ending (M): Dossier pick (Veteran / Archivist / Debtor), carry rules per ending (table above).

## Bot-measurable acceptance (tools/factory_eval.sh 1-10, 60 d; kx_pillar_table for the pillar)
- Submit: launch >= 3/10 at 60 d; alive>=8 >= 8/10; audit >= 7; P1 >= 5; P3 >= 3. Pillar gap >= 2.0 (standard_term d21).
- Fight (new `fight_bot` knob in factory_bot): Uplink built on >= 3/10 at 90 d, Collector assault won >= 1/10.
- Escape: suspicion never hits 100 on >= 7/10 when the bot sells at the "safe" cadence (one sale per 6 d); bandit fee
  reached on >= 2/10 at 90 d. Remission: contamination < 0.1 for 15 d on >= 2/10 at 90 d with pylons + cure bill.
- Unit: strength formula at 0/50/100% inputs; PoNR irreversible; replay of a run with `path` + set_manifest commands.
- Goldens: regen expected only if a scenario crosses the truth beat (none today); any other change = bug.

## Worker breakdown (one wave, disjoint files, start from claude/colony-sim-godot-4jftsm; bot worker last)
W1 "Path helper + PoNR + fuel" (M). Owns: sim/core/simulation.gd (`# region EN`: `path()`, `ending_won(id)` -> bus `ending_won`),
   new sim/endings/ending_system.gd (reads Q14 flags, PoNR per path, `path_locked`), data/endings.json,
   data/recipes.json + data/research.json (C1), tests/test_endings_path.gd, tests/test_dirty_fuel.gd.
   Accept: PoNR locks the path (Q14b refused after); petitions refuse delivery once a non-submit path is locked (no path
   = today's behaviour, so tutorial/goldens unchanged);
   dirty cell refines at a refinery, emits batch_refined + waste; goldens unchanged (make_golden prints 0 changed ticks).
W2 "Submit + manifest + siege" (M). Owns: sim/shuttle/shuttle_system.gd, data/shuttle.json, sim/threats/threat_system.gd
   (only `start_wave(strength_mult := 1.0)` in `# region EN`), sim/meta/legacy.gd (freed/stayed), tests/test_s1_shuttle.gd,
   tests/test_shuttle_manifest.gd. Accept: seats = alive colonists by default, `set_manifest` lowers the need; siege
   strength = base x (1 + pollution_frac) unit-tested at 0/0.5/1.0; notices (C4) stepwise and stop at launch; save/load/replay.
W3 "Escape economy + Fight endgame structure" (L -> split if needed). Owns: sim/contracts/contract_system.gd (`# region EN`:
   credits, suspicion, buyers from contracts.json `buyers`), data/contracts.json, data/buildings.json (`uplink_array`),
   sim/endings/fight_escape.gd (Collector assault = 3 scripted raids over 2 d via start_wave(strength_mult) then
   `ending_won("fight")`; bandit pickup = countdown + pursuit wave then `ending_won("escape")`), tests/test_escape_economy.gd,
   tests/test_fight_ending.gd. Metropolis raids themselves (defiance clock, drones) are the threats lead's `metro_track`;
   W3 only calls start_wave. Accept: suspicion formula + 100 => seizure raid; credits survive save/load; both ending_won
   paths replay-deterministic. Remission (E4) is W3b if a 5th worker exists: `cure` recipe is W1's file, so W3b owns only
   sim/contamination (reader) + pylons.
W4 "Endings bot + eval" (M, tools only). Owns: tools/factory_bot.gd (`# region EN`), tools/shuttle_bot.gd,
   tools/factory_eval_summary.py (columns: path, launch_day, seats, suspicion, raid_tier), tests/test_u4_factory_bot.gd.
   Accept: the numbers above; per-seed report of ending reached and day; hand-haul of rock-bound copper miners (RP trick).
Orchestrator: merge W1 -> W2 -> W3 -> W4; kx_pillar_table + factory_eval before main; log C2/C3/E4 as "decided without
owner, review". If time is short: ship W1 + W2 (Submit path = today's shuttle, now with path and seats) and defer W3.
