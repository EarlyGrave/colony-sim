# Round 4 - Midgame beats per path (days 20-60) - story writer, 2026-10-20
Docs only. Ids `r4_` (free). Game text <=70 chars/line.
Tags: [DATA] = existing verbs (flag/letter/mod/items/standing/block_standing/debt_pct/pollution/
mood/spawn_colonist/spawn_enemy/gamble/informant_standing). [NEW] = needs code (tiny).
Triggers use existing conds: flag, not_flag, min_day, quest_done, pollution_over, suspicion_over,
installment_missed, block_standing_below/above, informant_alive, rv_roll_call. Path flags: path_submit/
path_fight/path_escape (set by verb `path`). Mimic name: flag buried_mimic or rv_roll_call = Q15 done.
New conds [NEW, 1 line each in society_conds/metro_track]: `raids_survived N` (metro raids repelled),
`defiance_over N`, `gear_owned N` (count of GearItems on colonists/stored). New verb [NEW]: `trait
{who,id}` (grants acquired trait: hardened/resigned/jittery) and `gear {slot|base,rarity}` (loot roll).
Every [NEW] has a [DATA] fallback so the quest ships without it.
## LINE A - SUBMIT: "Good Behaviour" (r4_good_behaviour, d28+, 4 beats)
Trigger: flag path_submit, min_day 28. Theme: the deal is generous at the start. Then it is itemised.
A1 `bonus` [DATA] Dispatch "Form 3-S/b: early pickup". Text: "The Procurator offers
  a bonus pickup. Credit: generous. Terms: waived. Deadline: yesterday."
  - Accept: debt_pct -8, pollution +6 (do 1 extra shipment), flag r4_bonus, standing Lifers +5.
  - Decline: block_standing Lifers -6, mood +0, flag r4_declined (A2 text changes: "You declined.").
A2 `seats` [DATA] (delay 3 d) Seat list arrives. Text: "Seat 7: Inmate 4471, reinstated." If
  buried_mimic/rv_roll_call: the name is a dead colonist's (the mimic's). Hint: "It knew the door code."
  - Strike the name: block_standing Clerks +8, Zealots +4, debt_pct +2 (paperwork fee), flag r4_struck.
  - Leave it: Lifers +8, informant_standing +5, flag r4_seat_kept, letter "Seat 7 confirmed. Occupied."
  Echo [NEW]: r4_seat_kept adds an epilogue line: "Seat 7 stayed empty. Someone kept the door."
A3 `gear_check` [DATA] (needs min_day 40) Warden: "Equipment not on the manifest is
  contraband. Armour is equipment." Colonists hold looted vests/helmets (F2c/F3a).
  - Hand over: items plates -10 (requires items plates 10; [NEW gear_owned >= 2] to gate), Lifers +6,
    mod wave_mult 0.9 for 5 d ("The Warden lends you a quieter week.").
  - Keep it hidden: flag r4_hidden_gear, mod wave_mult 1.1 for 10 d (audit parts), Informant -> chance
    of snitch: gamble p0.4 win=[letter "Search: vests found.", debt_pct +4, standing all blocks -4],
    lose=[letter "Search: nothing found. Mostly."].
A4 `recount` [DATA] (delay 4 d after A3) Scar beat. Dispatch: "A guard assessed our wounded.
  Scarred inmates are billed at the old rate." Chosen once:
  - Pay the scar tax: debt_pct +3, mood_block all +3 thought `scar_billed` (text only).
  - Refuse: block_standing Lifers -5, flag r4_refused, [NEW trait: hardened on the loudest colonist]
    fallback [DATA]: standing Zealots +6.
## LINE B - FIGHT: "Drone Toll" (r4_drone_toll, d30+, 4 beats)
Trigger: flag path_fight, min_day 30, [NEW raids_survived 1]; fallback [DATA]: flag path_fight + min_day 36.
B1 `wreck` [DATA] Text: "A drone came down inside the fence. It is still warm. It is also
  still counting." (kill feed/letter after the first repelled raid)
  - Strip it: gear loot [NEW gear base=plasma_blade|smg rarity uncommon] fallback items plates +6,
    pollution +3, flag r4_stripped.
  - Burn it where it lies: pollution +6, Zealots +8, flag r4_burned, mod wave_mult 0.95 for 5 d (smoke).
B2 `pilot` [DATA] (delay 2 d) Drone shell holds a living Metropolis tech. Text: "The pilot is
  four digits tall. His number is in our ledger. He wore it on his sleeve."
  - Interrogate: gamble p0.5 win=[flag r4_know_route, mod wave_mult 0.85 for 10 d] lose=[mood_block Fresh Fish -6,
    letter "He told us what we told him."].
  - Recruit him: spawn_colonist (name taken from an inmate dead >10 d: bio.name = dead name, a mimic name
    reused), standing Fresh Fish +10, informant_standing -5, flag r4_pilot.
  - Send him back with a message: block_standing Clerks +8, Zealots -8, flag r4_letter, defiance +8 [NEW
    defiance verb] fallback: mod wave_mult 1.1 for 10 d.
B3 `strike_vote` [DATA] (needs block_standing_below 20 on any block OR min_day 45) Ultimatum letter:
  Zealots want refining stopped for 2 days. "Stop the stacks. Let the ground breathe."
  - Stop: mod refining 0 for 2 d (existing mod name to verify), pollution -4, Zealots +15, debt_pct +0.
  - Refuse: Zealots -12, Lifers +6, flag r4_no_pause.
B4 `scars` After 3 raids: "The scars are in the wall now. Also in us."
  - Wear them: [NEW trait hardened x2] fallback mood +4 all. Cover the walls: items plates -4, mood +2.
## LINE C - ESCAPE: "Quiet Freight" (r4_quiet_freight, d35+, 4 beats)
Trigger: flag path_escape, min_day 35. Theme: the exit is a market and every market has a clerk.
C1 `manifest` [DATA] Ferry broker: "The Ferry does not ask who. It asks how many. The
  Ferry asks for a name to put on each crate."
  - Sell a dead inmate's ID (uses mimic name; only offered if rv_roll_call): escape credit +
    [NEW verb credit {n}] fallback items refined +10; suspicion +6 [NEW suspicion verb] fallback none;
    flag r4_sold_name; Lifers -10 ("You sold his number.").
  - Use a made-up name: no credit, safe; Clerks +6, flag r4_cover_name.
C2 `inspection` [DATA] Trigger suspicion_over 40 (cond exists). Letter "Friendly inspection".
  - Open every door: stash and 10 refined seized (items refined -10), suspicion drops [NEW];
    fallback mod audit 0.8 for 8 d; Lifers +4.
  - Bribe the Informant: informant_standing +12, debt_pct +3, Clerks -5, informant_alive required.
  - Move the stash into the dump: pollution +4, flag r4_dumped, requires r4_cover_name or not.
C3 `courier` [DATA] (delay 3 d) The Ferry's courier arrives with a cage. Text: "Cargo: one crawler.
  Fed, quiet, labelled with a name. Not ours to read." If buried_mimic: the label shows a name that
  was in your Roll Call.
  - Accept the cage (it is a mimic, harmless for 10 d): flag r4_caged, gamble p0.35 lose=spawn_enemy
    mimic at the fence; win=[escape credit +, letter "It sat. It did not bite."].
  - Refuse: Zealots +6, Ferry price +[NEW] fallback debt_pct +2.
C4 `drone_tail` [DATA] Once suspicion_over 60 AND drones seen: "A scout drone is following
  the Ferry's signal." Options: Jam it (items plates -6, wave_mult 0.9 for 6 d) / Let it pass (suspicion
  stays, flag r4_tailed; extraction event has +1 drone row [NEW]).
## WARDEN PA LINES (add to flavor.json pa.*, region story; trigger by flag on beat entry)
1. r4_good_behaviour: "A bonus is a loan with better lighting."
2. "Seat 7 is reserved. Please do not ask for whom."
3. "Armour is a form of ambition. Ambition is recorded."
4. r4_drone_toll: "Drone 12 failed to return. Drone 13 has been informed."
5. "Pilots are replaceable. So are walls. Please choose."
6. "Smoke on the horizon. The Warden suggests it is yours."
7. r4_quiet_freight: "A crate is not a sale. A sale is not a crate. File both."
8. "Suspicion is at 60. The Warden is only curious. Loudly."
9. any path d40+: "Scars are non-refundable. Scars are also property."
10. "Mid-term review: you are alive. This was not an assumption."
## LETTERS (title / text, <=70 chars/line)
L1 "Form 3-S/b" - "Bonus pickup approved. Terms apply. The terms are you." (A1)
L2 "Salvage Notice" - "Drone wreck is property of the Metropolis. Finders are property too." (B1)
L3 "Pilot's Note" (B2) - "Tell them the ground is awake. Tell them we have names."
L4 "Cargo Label" (C3) - "Name: [dead inmate]. Species: formerly. Handle with calm."
## Wiring notes for the prompter
- All [DATA]: new file data/quests_r4.json (3 quests) + flavor.json pa lines; loader already globs quests_*.
- [NEW] list: conds raids_survived/defiance_over/gear_owned (3 lambdas), verb `trait`, verb `credit`
  (escape_credit), verb `suspicion`, verb `defiance`; each optional. Mimic name in text via placeholder {dead}   [NEW tiny: sim.quests fills {dead} from Enemy.name_of_dead / last colonist death]; fallback static text.
- Tests: each quest done on forced flags (pattern test_story_paths); text <=70/line; goldens unchanged.
- Remission undecided: no beat touches it.
