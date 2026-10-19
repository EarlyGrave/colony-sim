# The Revelation Arc - landing to ending choice (Fable, 2026-10-19)
Source: owner notes 2026-10-19, bible v2, GDD §4/§6, society_narrative.md. Docs only; in-game text
English, <=70 chars/line. Tags: [EXISTS] = shipped quest/system, [NEW] = needs a quest or trigger.

## 0. Shape of the arc
Landing -> first pickup -> first wave (the pillar, felt) -> 5 clues (layers R1-R4 + one new) ->
the inmates learn the creatures were people (R2 made public) -> Lull reveal (R5, Q14) -> Procurator's
deal -> path -> endgame -> epilogue. Rule: before Q14 every path is the same game (GDD §6).

## 1. Landing (day 0) [EXISTS: start letter; tweak text only]
Letter "Intake": "Sentence: life. Location: here. Quota: attached. Welcome is not."
PA: "Inmates, the air is breathable. This is the last free thing."

## 2. First batch -> first wave (day ~3.5) [EXISTS: first_wave_delay_days; NEW: gate on pickup]
Today the first wave fires on a timer. Beat: the swarm should arrive the night AFTER the first
refined batch leaves (bus `shuttle_phase("departed")` or first `debt_paid`), else at the timer.
PA before: "Shipment 1 departed. The planet has noticed."
Wave letter "Incident 1": "Local fauna approached the refinery. Fauna is not local anymore."
One line of dread (bible): "They came from the dump side. They did not come from anywhere else."
Idea: the swarm spawns at the tile with the highest pollution, not at the map edge (ThreatSystem
spawn hint). The player sees cause and effect once, in the tutorial wave.

## 3. Clue beats (flags read by Q14 `clues_held`)
| # | beat | source | trigger | flag |
|---|---|---|---|---|
| C1 Yield | Auditor's manifest counts essence in "calm units" | Q6 [EXISTS] | show everything | clue_manifest |
| C2 Handwriting | a mimic hums an inmate ID; study it | Q8 [EXISTS] | pollution_over 70, study | clue_survey_tag |
| C3 The slip | PA maintenance leaks a quota screen: "LULL / batch" | Q10 [EXISTS] | missed installment, respect | clue_warden_quota |
| C4 The buyer | black-market buyer asks for "the calm stuff" | S4b [EXISTS] | stash > 6, let it ride | clue_buyer |
| C5 The dead return | a mimic wears the face of YOUR dead colonist | [NEW Q15 "Roll Call"] | first mimic wave after a colonist death; mimic def gets `name_of_dead` | clue_our_dead |
| C6 Lifer's receipt | the Lifer shows a prior-sentence receipt: "Lull, 40 units, paid" | [NEW Q16, cheap] | min_day 25 + lifer block standing >= 60 | clue_receipt |
Each clue letter ends with one line of truth (bible): C1 "Calm is not a unit of fuel."; C2 "The ID is
four digits. Ours are four digits."; C3 "The screen said Lull. Then it said sorry."; C4 "Not for the
money. For the calm."; C5 "It knew the door code."; C6 "Receipts outlive sentences."
C5 and C6 exist so Q14 can fire for players who hide pollution (skip C1) and never skim (skip C4).

## 4. The inmates learn the creatures were people [NEW Q15 "Roll Call", M]
Trigger: C2 or C5 held AND a mimic killed inside the fence. Beat 1: the body is counted at roll call
and the count is one too many. Beat 2 options: Bury it as an inmate (Zealots +10, Lifers -5, flag
`buried_mimic`) / Burn it with the waste (pollution +5, Informant +5) / Send the tag to the Warden
(Warden reply "Record found. Record sealed.", debt_pct -2). After Q15 the Blocks panel shows the
line "Creatures: former inmates (confirmed)" and the Zealot sabotage event unlocks (S-quests).
Lines: "Roll call: 11 present, 10 alive." / "It had a number. The number is in our ledger."
Dread line: "Nobody said it. Everyone counted again."

## 5. The drug reveal + the Procurator's deal [EXISTS: Q14 Three Forms]
Q14 `land` is the Metropolis contact; `small_print` is the Lull reveal; `choose` is the deal.
Add [NEW text only]: the Procurator's voice line before `land`: "Procurator to site. Your file is
excellent. Your planet is not." On `choose`, the Submit hint should quote the deal verbatim:
"Deliver 3 more pickups. Receive: components, seats, new names. Keep: nothing."
Remission is not a Q14 form: it opens later (Q17) so Q14 keeps three buttons on a phone.

## 6. Remission path entry [NEW Q17 "Reversal", M; after GDD E4 cure recipe exists]
Trigger: any path chosen (or none) + first `cure` bill completed + contamination falling 3 days.
Beat: the Zealot reports a crawler that stopped at the pylon and sat down. Option "File for
remission" sets `path_remission` (does not clear the Q14 path; the shuttle reads remission first
when contamination < 0.1 for 15 d). Letter: "Form 0-R: Remission. No such form exists. Filed."

## 7. Epilogues (shown on the ending screen; 4-6 lines each)
**Submit** - "Case closed. Cause: silence."
The last shuttle lifts with every seat full. Nobody looks down.
Below, the planet finishes going mad on its own. It is logged as weather.
You receive new names. They are shorter than the old ones.
Somewhere a city is calm tonight. You made the calm. Do not mention it.
Your file is excellent. It has always been someone else's.
**Fight** - "Collector offline. Quota: unresolved."
The Collector falls for eleven minutes and is a sunrise for one.
Drone shuttles stop. The Warden's PA plays a maintenance tone, then nothing.
The creatures keep their distance. Less waste, less memory, less teeth.
You are still sentenced. Nobody is left to count it.
The planet is free for a long time. Not forever. Long enough to plant.
**Escape** - "Transfer complete. Destination: not on file."
The Ferry lands where the map said it would, and is late, and is enough.
You pay in calm. They do not ask what calm is. They already know.
The Warden files your departure as unauthorised and then as unlikely.
Behind you the refinery is still warm. Someone else will be sent to dig.
You are free in a sector that buys what you sold. Spend carefully.
**Remission** - "Form 0-R approved. By nobody."
The pylons hum the other way. The ground remembers how to be ground.
A crawler sits at the fence and does not come closer. It is waiting to be a person.
The quota is still met. The Procurator notices nothing, which is the plan.
Later, the first remitted inmate walks in through the gate with a four-digit name.
You stay. It is the only ending where staying is the win.

## 8. Warden PA / letter lines (20, in-game style, add to flavor.json region N1)
1. "Shipment 1 departed. The planet has noticed."
2. "Your quota is a living document. It is also living."
3. "Fauna is reclassified as 'residents'. Residents are hostile."
4. "The Auditor counts in calm units. Do not ask what calm weighs."
5. "Maintenance window closed. Any words you saw were a test."
6. "A buyer is not a visitor. A visitor is not a buyer. File both."
7. "Roll call: 11 present, 10 alive. Please recount."
8. "Records of prior inmates are sealed. Their teeth are not."
9. "Procurator inbound. Shave, if applicable."
10. "Form 3-S: continued service. The alternative is also service."
11. "Lull is a rumour. Rumours are deducted from rations."
12. "Resistance is logged. Logging is the Warden's only weapon. Mostly."
13. "Drone shuttle on approach. It brings nothing. It takes."
14. "Departure forms are not accepted. They are, however, kept."
15. "Suspicion is at 60. The Warden has ordered a friendly inspection."
16. "Your installments are suspended. So is the Warden's patience."
17. "Contamination is falling. This was not requested. Noted."
18. "Congratulations on surviving. Surviving is billable."
19. "The Collector thanks you for your silence. It cannot hear you anyway."
20. "The Warden regrets. Form 9-A: regret withdrawn."

## 9. Summary of new work
NEW: first-wave gate on first pickup + dump-side spawn (S, threats); Q15 Roll Call (M, data + mimic
`name_of_dead`); Q16 Lifer's Receipt (S, data); Q17 Reversal (M, after E4); Q14 text additions (S);
20 PA lines + 4 epilogues (S, flavor.json / ending screen). EXISTS: Q6, Q8, Q10, S4, Q14, Q14b.
