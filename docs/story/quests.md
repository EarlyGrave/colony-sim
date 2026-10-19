# Quest lines (data-driven; events.json-style unless flagged)
Common mechanism: a `quest` entry (id, trigger, beats[], choices[]) driven by Storyteller; beats are letters/choice events. NEW SYSTEM (shared, S/M): a tiny `QuestLog` (state per quest id + flags, saved/deterministic via sim.rng) + `data/quests.json`. Without it, each quest falls back to chained events with `requires_flag`.

## Q1 The Clerk's Margin Note  [cost M]
- Trigger: first debt payment >=1 refined AND a Clerk wanderer joined (wanderer event).
- Beats: (1) Clerk finds an interest clause on the ledger; (2) offers a "loophole": hide refined from audit; (3) Warden notices an "inconsistency"; (4) payoff.
- Choice: Use loophole (-25% debt on that inmate, +audit heat -> next audit costs +20% parts, Clerk may be "reassigned"= removed) / Report him (Warden gives +10 refined allowance, Clerk's mood -, may despair-escape) / Ignore (nothing, Clerk later leaks a clue).
- Touches: events.json (wanderer variant), debt in ColonistSystem, flavor.json, audits (milestones.json).
- Lines: "Clause 14(c): interest accrues on the debtor. Not the debt." / Warden: "A discrepancy has been located. It was not hidden well."

## Q2 Pilgrims of the Slag  [S/M]
- Trigger: pollution > 40% for the first time.
- Beats: (1) A Zealot among inmates preaches "the planet is judging"; (2) night prayer at waste dump; (3) a creature wave arrives *to the prayer site*, not the base; (4) outcome.
- Choice: Let him pray (waves spawn 30 s later and at the dump: free time to prepare, Zealot dies 50%) / Silence him (-mood group, no change) / Join (Zealot recruits 1 more; refining output -15% for 2 d, but waves -20% for 3 d).
- Touches: events.json (choice kind), ThreatSystem spawn_point override (small), rules.
- Lines: "Brother Oto says the dust is a verdict. Please file your own." / "He is singing to the slag. The slag is listening."

## Q3 The Parole Board Loves You (Review gambit)  [M]
- Trigger: Parole Review R2 reached.
- Beats: (1) Board hints "contributions of a particular nature" would help; (2) offer: sponsor a Warden gala (cost 20 refined essence); (3) result letter; (4) Board returns with a catch.
- Choice: Sponsor (rank +1 sooner, but petition fee +10% at p1) / Decline (rank on schedule) / Bribe the Informant (Informant gives future audit dates: next audit tier gets -20% cost; he stays a spy for the Warden).
- Touches: parole code (rank), petitions.json (fee mult), items.
- Lines: "The Board welcomes gifts. The Board welcomes the gifts you will inevitably give." / "Your rank has improved. Your standing has not."

## Q4 The Gantry Signal (Petition mystery)  [M]
- Trigger: Petition phase 2 done.
- Beats: (1) the evidence delivery returns with an unlabeled return crate; (2) the crate hums in refined voices (old inmates' IDs); (3) Fresh Fish hears the names on the PA; (4) decision on the contents.
- Choice: Open the crate (+refined 30, but ghost-sound event: -mood all 1 d, reveals Company clue = NG+ fragment) / Burn it (+pollution 5%, creature wave small) / Return it unopened (Warden praises compliance: Review +1 point).
- Touches: petitions.json reward hook, flavor.json, items (crate), mood.
- Lines: "Returned item: 1 crate. Contents: 'ongoing'." / "Someone in the crate is reading your name."

## Q5 Outpost 7 Does Not Answer  [M/L]
- Trigger: first expedition/outpost completed.
- Beats: (1) outpost goes silent after day 3; (2) send a rescue squad (expedition mechanic) ; (3) find outpost mining crew *with creature-grown mimics* of themselves; (4) choose.
- Choice: Bring back the "survivors" (+2 colonists, but one is a mimic: hidden, defects during a later wave and opens the gate) / Burn the outpost (lose outpost income, -waves 3 d) / Leave a beacon (Penance Beacon cheaper, mimics become neutral).
- Touches: expeditions system, events.json, ThreatSystem (traitor flag = NEW logic S).
- Lines: "Outpost 7 reports all is well. Outpost 7 has reported that four times." / "He waved like a man who learned waving yesterday."

## Q6 Sector Dispatch: The Auditor Visits  [S]
- Trigger: audit tier 2 passed.
- Beats: (1) a Dispatch announces a Company Auditor; (2) inspect: clean base wins a cut, polluted base gets fined; (3) Auditor "accidentally" shows an orbital manifest ("Biomass: forecast").
- Choice: Hide pollution (spend 30 plates tarp: fine avoided now, waves +20% later) / Show everything (fine 10% debt; Auditor leaves a clue) / Offer the Auditor a tour of the dump (he gets shaken, petition -5% fee).
- Touches: events.json (dispatch kind), contamination (visibility flag), debt.
- Lines: "Auditor Pell requests a clean room. We have not been told what that is." / "Pell notes: 'crop yield exceeds expectations.'"

## Q7 The Informant's Ration  [S]
- Trigger: colonist count >=6 and 1 colonist has the Informant trait (new trait string, data only).
- Beats: (1) rations quietly dip for loyal inmates; (2) a colonist whispers who; (3) choose.
- Choice: Expose him (mood -, he's confined at jail cell or exiled) / Feed him lies (cost 5 refined: Warden's PA blocks a wave hint = next wave delayed) / Let him live (Warden gets intel: threat event predictions revealed?? - no, you see them first).
- Touches: ColonistSystem traits, flavor.json, ThreatSystem delay.
- Lines: "Someone is telling the Warden things. The Warden is delighted." / "Ration adjustment: for loyalty."

## Q8 What the Creatures Wear (Mimics arc)  [L]
- Trigger: 3rd big wave or pollution >70%.
- Beats: (1) waves bring dropped items shaped like earlier waste; (2) first mimic walks in as an inmate; (3) mimic hums an old inmate's name; (4) final: find the first survey crew's tag in a nest.
- Choice: Study (+1 research point, creatures drop essence 2 d) / Cleanse (spend 40 plates + essence: pollution -15%, mimics stop for 5 d) / Feed them (dump waste at a Penance Beacon: no waves for 2 d, pollution +10%).
- Touches: ThreatSystem (new enemy variant data), research, beacons, NEW: mimic enemy def (S).
- Lines: "It has your sentence number. It has your handwriting." / "We are all just ledger entries with legs."

## Q9 Next Sentence (NG+ capstone)  [L]
- Trigger: Shuttle win -> Continue or Next.
- Beats: (1) docking letter: "Balance carried forward"; (2) choose a Dossier carry-over (colonist, perk, secret); (3) new colony, one mystery fragment already known; (4) 5th loop: Warden quota screen.
- Choice: Which Dossier perk: Veteran (1 colonist with +skill) / Archivist (start with a revealed clue = hint panel) / Debtor (start debt x1.5, essence x1.5).
- Touches: NEW NG+ state persisted across runs (meta file), Simulation.new seed+carry dict, win screen, scenarios.
- Lines: "Your release has been processed. Your debt has been rolled over." / "Welcome back. You were never here."

## Q10 Warden Maintenance Window  [S]
- Trigger: day 40 or after any 3 deaths in a week (either).
- Beats: (1) PA goes silent for 6 h (no letters/dispatch); (2) guards drop supplies unmanned; (3) PA returns with an apology form ("Humanity module reinstalled").
- Choice: Raid the supply cache (+refined, +parts but Review -1 rank) / Respect the quiet (nothing; Warden reveals one mystery line) / Sabotage the terminal (disables PA 3 d; audits impossible 3 d).
- Touches: events.json, flavor.json suppression flag (tiny), milestones/audits gating.
- Lines: "The Warden is currently out of the office. The office is out of the Warden." / "Apology form 9-A: 'We regret nothing, in writing.'"

## Priorities
Build order: Q6 (S, uses dispatch/audits, hits the mystery), Q2 (S/M, ties pollution to waves), Q1 (M, debt hook; best narrative mileage). Q9 is the retention feature once the NG+ meta file exists.
