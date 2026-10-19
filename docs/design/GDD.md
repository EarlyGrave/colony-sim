# GDD — "Sentence Ended" (master game design document, v1, 2026-10-19)
Owner: game designer (Fable). Source of truth for story and direction: docs/design/owner_notes_2026-10-19.md
(numbers there and here are DIRECTION, every number goes through a balance cycle with bot tables).
Lead docs (this GDD integrates them, they own the detail and the worker breakdowns):
- Economy & endings: docs/design/economy_endgame.md
- Society & narrative: docs/design/society_narrative.md (+ docs/story/bible.md, quests.md, society.md)
- Threats & pacing: docs/design/threats_pacing.md
- Combat & items: docs/design/combat_items.md
- Progression & traits: docs/design/progression_traits.md
- Process: CLAUDE.md (orchestrator / prompter / workers, ship checks), DECISIONS.md, PROGRESS.md.

## 1. One-paragraph pitch
A phone-first colony sim ("RimWorld meets Factorio") on a prison planet. Lifers who chose hard labour over
execution must deliver a quota of refined Essence to the Metropolis' pickup shuttle. **Mining is safe, refining
is dangerous**: refining waste poisons the land and drives the planet's creatures (former people and animals)
mad; the faster you refine, the harder they come. The Metropolis needs the Essence for a euphoric drug that
keeps its cities quiet, which is why this is done on a far planet by the condemned. When the colony learns
that, it chooses: Submit, Fight, Escape — or (proposed) Remission.

## 2. Pillars (every feature must serve at least one, none may break #1)
1. Mining safe, refining dangerous. Measured: `kx_pillar_table` gap >= 2 waves by d21 (today 6.2 vs 4.0).
2. Choices are legible on a phone: big buttons, one number per decision, the cost quoted in the hint.
3. Deterministic sim, data-driven numbers (`sim/` RefCounted, `data/*.json`), bot-measurable before merge.
4. Everything awful arrives as a form (tone: bureaucratic dark comedy over real dread; all text English).
5. The colony is people: blocks, standing, traits and the Informant make the society visible and consequential.

## 3. Core loop (minute / day / sentence)
- Minute: designate mining, place machines and belts, set bills, draft a squad, read a letter, answer a quest.
- Day: ore -> refinery (dirty) or smelter/assembler (clean) -> plates/parts/cells; feed the quota, research,
  turrets; creature wave or inspection; needs, mood, despair; a storyteller beat tied to the threat state.
- Sentence (run, 40-90 days): quota pickups and inspections -> clues -> the truth (Q14) -> a path -> point of no
  return -> ending -> legacy + Next Sentence.

## 4. World and story (bible, owner canon)
- Setting: far penal planet; colonists are death-row lifers; the Metropolis is the antagonist faction, the Warden
  its PA-system voice; jailers (Procurator, inspections) are its hands; the orbital Collector sends drone shuttles.
- Essence: valuable ore; refined it is currency, fuel and the Metropolis' drug precursor. Waste = poison.
- Creatures: poisoned former people/animals; refining tempo raises hostility (scent clock). Mimics reveal it.
- Truth beat: Q14 "Three Forms" (society doc) after 2 clues + day 30; the player picks a path; one amendment.
- Detail: docs/story/bible.md (tone, Warden, Metropolis, creatures, archetypes), docs/story/quests.md.

## 5. Economy (economy_endgame.md)
- Resources: essence_ore -> refined_essence (ONLY polluting recipe, owner rule) ; iron/copper -> ingots -> plates ->
  parts (clean); nitrogen -> fuel cells (clean) or dirty cells at the refinery (C1, polluting); coal/nitrogen/uranium power.
- Quota (today's DebtSystem): per-lifer norm, installments per pickup, grace, despair -> riot/escape. Pickup shuttle
  every `period_days`. Side orders (contracts), inspections (audits, tier gates), Compliance Deal (petitions, Submit).
- Problems fixed this pass: one currency/seven sinks, debt as a tax, shuttle as a shopping list, pillar biting once.
- Changes: C1 dirty fuel, C2 siege/raid strength from path state, C3 manifest seats, C4 launch window, C5 credits +
  suspicion (Escape), C6 Next Sentence by ending. Bot acceptance: launch >= 3/10 at 60 d, alive>=8 >= 8/10, pillar >= 2.

## 6. Endings (owner canon + proposal; mechanics in economy_endgame.md, raids in threats_pacing.md 2b)
| path | PoNR | mid-game pressure | endgame | after |
|---|---|---|---|---|
| Submit (bad) | accept Compliance Deal | quota + petitions, pollution climbs | Extraction Platform, seats, madness siege (x 1+pollution) | planet destroyed; Next Sentence "New Names" |
| Fight (good) | first refused pickup | defiance -> Metropolis drone raids (energy) ; creatures calmer | Uplink Array + Collector assault (3 raids / 2 d) | free planet, Continue sandbox, legacy x2 |
| Escape (grey) | bandit contact | covert sales -> credits, suspicion (Informant, inspections) | bandit fee, walk to a world-map point, pursuit | Next Sentence "New Sector" (credits 10%) |
| Remission (proposed 4th) | cure bill started | keep quota, cure the land (pylons), contamination < 0.1 for 15 d | remitted inmates join; creatures calm | stay; the only ending that rewards refining less |
Rule: before Q14 all paths are the same game; the early game stays one tutorialised loop (R5 tutorial unchanged).

## 7. Threats and pacing (threats_pacing.md)
- Three clocks: pollution (creatures), sentence (inspections), essence hoard; scent clock + dormancy windows make
  the risk legible and timed, never smaller on average. Raids get objectives (gorge / wreck / nest / hunt) and a
  district lockdown instead of the global alarm; mine huts shelter remote miners.
- Second track: Metropolis raids keyed by defiance (quota refused, audits declined), energy damage, drop spawns,
  never on the same day as a creature wave. Submit sees 0 by d60; Fight escalates to the Collector assault.
- Storyteller reads the threat state (`requires` on events).

## 8. Combat and equipment (combat_items.md)
- One hit roll (accuracy only, no evasion stat), one damage function: flat reduction, then LoL-style armor
  `100/(100+armor)`, min 1, physical and energy ratings, penetration ignores % of rating. ~15 ops, no loops.
- Slots head / hands / legs / torso-outer / torso-inner, data-driven (`data/equipment.json`); durability stored,
  not destructive; affixes PoE-style grouped attack / defence / utility with rarity-scaled counts.
- Phone budget: 200+ equipped units in one raid; affixes are pre-summed into a per-unit stat block at equip time,
  never rolled per hit. Melee and ranged weapon families as data; skill-driven.

## 9. Progression and traits (progression_traits.md)
- Skills 0-10, XP by use (fights, range training, benches), non-linear table (~1.6x per level), efficiency curve
  0->30% ... 3->100% ... 10->200-250%, each level a letter. Branches (sniper / monk / forester...) designed, later.
- Traits v2: weighted rarity, mutually exclusive groups, physical + character, each useful in a niche; feed
  blocks' Standing, despair and the Dossier.

## 10. Society (society_narrative.md)
- Cell blocks with Standing (the vote), Informant, contraband re-aimed as covert trade (Escape), S5 NG+ quest.
  Q14 posts each block's leaning; opposing the strongest block is the memorable decision. The player sees the
  society on a phone-sized sheet.

## 11. Meta: legacy and Next Sentence
- Legacy points per day / contract / freed / stayed / perk; unlock shop (meta.json). Next Sentence carries a
  Dossier (Veteran / Archivist / Debtor), techs, and per-ending rules (table in §6); sentence number scales the
  Metropolis' interest in you (C2). Fifth loop shows the Warden's quota screen (bible).

## 12. UX and platform
- Godot 4.7 GDScript, GL Compatibility, single-threaded web build, GitHub Pages; pseudo-3D view, 16 px/cell.
- Touch-first: >= 64 px buttons, no hover/right-click, content_scale by DPR; web smoke at 844x390.
- Letters + quest sheet are the main narrative surface; the forecast ticker is the pillar's gauge.

## 13. Measurement (ship checks, CLAUDE.md 9)
- Full suite green; `tools/web_smoke.py` PASS; goldens regen only for an INTENDED sim change.
- Bot tables before main: `tools/factory_eval.sh` (survival, audit, P1/P3, launch, ending reached, day),
  `tools/kx_pillar_table.gd` (pillar gap), per-lead acceptance blocks in the four docs.
- Owner feedback: phone screenshot + one blunt sentence -> one task.

## 14. Build order (one wave per batch, 3-5 Sonnet workers, disjoint files; see each doc's breakdown)
1. Economy W1+W2 (path helper, PoNR, dirty fuel, manifest/siege) + society W(Q14) + threats skeleton (metro clock off).
2. Threats wave (objectives, scent, lockdown, mine hut) + combat pipeline/equipment + progression XP table.
3. Fight/Escape endgame structures (economy W3) + Metropolis raids live + traits v2.
4. Remission (E4), Next Sentence by ending, branches, society emergent beats; balance cycles between every step.
Cut list if time is short: Remission, skill branches, affix UI; never cut pillar measurement.

## 15. Open questions for the owner
- Fourth ending: Remission (stay, cure the land) vs "Broadcast" (ship the lab report to the capital, political win)?
- Should the Fight path keep the pickup shuttle landing (looting it) or leave empty? (affects Metropolis pacing).
- Evasion stat dropped (combat doc) — confirm. Pre-summed affixes (no per-hit rolls) — confirm for phone budget.
- Does Next Sentence after Submit keep ANY colonist (new names = same people) or only the Dossier?
