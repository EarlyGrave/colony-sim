# Society quest lines (blocks / informant / contraband) - round 3
Verbs available: flag, mod, items, mood, debt_pct (2% colony cap), spawn_colonist, remove_colonist,
pollution, gamble, spawn_enemy, letter. Triggers: min_day, flag, not_flag, quest_done, tier_done,
pollution_over, reviews_done, sentence_min, carry_debt. NEW conds via register_cond (S each, data):
`block_standing_below {block,v}`, `block_standing_above`, `contraband_stash_over n`, `informant_alive`.
Text <=70 chars/line. Debt cuts stay clamped; never promise more than the 2% cap in hints.

## S1 Cohesion Fee  [S, data]
- Trigger: min_day 15 + block_standing_below {block:any, 30} + quest_done q13 not required.
- Beats: (1) Warden invoices the quietest block; (2) the block's elder asks you to cover it.
- Choices: Pay (items refined -15; flag block_covered; Standing +10 via mod despair_mult 0.9 5d) /
  Refuse (mood thought "Left to the Ledger" on that block; mod petition_fee_mult 1.05 3d) /
  Redirect (debt_pct +1 on the Lifer only: "he volunteered"; Lifer Standing +, others mood -).
- Warden: "Block C has been unusually peaceful. A fee has been applied."
  "Cohesion is a service. Services are billed."
  Letter: "Your quiet inmates have been noted. Quiet is not an exemption."

## S2 Pecking Order  [S/M, data]
- Trigger: a block Standing above 70 AND another below 30 (spread >= 40).
- Beats: (1) strong block starts "collecting" from weak one; (2) Fresh Fish reports a bruise.
- Choices: Separate cells (items plates -10; spread shrinks, flag blocks_split) /
  Look away (strong block Standing +, weak block mod despair 1.15 4d; Warden "efficiency +2%") /
  Let the Lifer mediate (gamble 0.6: win mood+ all, lose spawns a brawl: mood thought, no death).
- Warden: "Informal taxation has been observed. It was not authorized by us."
  "Inmate 4471 is bruised. This has been recorded as a lifestyle."
  Letter: "A Lifer says: 'It was worse before the paperwork.'"

## S3 Whisper Network (Informant x Petition)  [M, data; extends Q13]
- Trigger: quest_done q13 (tolerated outcome) + tier_done 2, or petition phase 1 reached.
- Beats: (1) the Informant's reports begin naming petition evidence; (2) Warden "adjusts" the review date.
- Choices: Feed him a decoy (items parts -5; mod petition_fee_mult 0.9 4d if Clerk alive, else fails) /
  Bait the Warden (gamble 0.5: win flag audit_dates_known + mod audit_parts_mult 0.8, lose
  mod petition_fee_mult 1.3 3d) / Cut him off (remove_colonist: transferred; block Standing -10; fee back to 1.0).
- Warden: "Your petition is progressing. Someone has been very helpful."
  "Inmate tip received: 'They are counting plates.' Thank you for your service."
  Letter: "Informant stipend: 2 rations. Source: you."

## S4 The Stash Inventory (Contraband)  [S/M, data; needs contraband ON]
- Trigger: contraband_stash_over 6 + min_day 25. (Quest is the on-ramp for the disabled shakedown.)
- Beats: (1) a Dispatch: "Unaccounted essence"; (2) the Clerk says the skim is pre-booked interest.
- Choices: Squad shakedown (recover stash as items refined; despair spike mod; flag shaken_down) /
  Let it ride (spawn_enemy mimic x1 at 40%; debt_pct -1 "black-market adjustment", once) /
  Turn it in to the Warden (flag warden_favor: next installment grace +1 d; Standing of skimmers -15).
- Warden: "Essence has gone missing. It has gone somewhere. We have no further questions."
  "A shakedown is a conversation with a larger audience."
  Letter: "Your colony has an economy we did not invoice."

## S5 Old Cells, New Faces (NG+ veterans)  [S, data]
- Trigger: sentence_min 2 + min_day 8 + flag veteran (block of the veteran pre-set at Standing 60).
- Beats: (1) the veteran finds their old block's marks on the wall; (2) a new Fresh Fish asks who ran it.
- Choices: Tell the truth (flag clue_loop; veteran mood -; Fresh Fish block Standing +10) /
  Pass the title on (Veteran becomes Block Boss: mod despair_mult 0.9 6d, mod refine_mult 0.95 6d) /
  Burn the marks (carry_debt: debt_pct -1 "records mislaid"; Warden suspects: mod audit_parts_mult 1.1 4d).
- Warden: "Welcome back to Block B. Block B regrets to inform you it remembers."
  "Seniority carries over. So does the invoice."
  Letter (loop 3+): "Your cell has been reserved. It was never released."

## Wiring notes
Mystery chain: S3 clue (audit dates) -> Q10 quota; S5 clue_loop -> Q11/Q12; S4 shows contraband is the
Company's own pre-booked skim (bible: debt is bait). Wire `pa.informant_report` flavor into S3 beats.
Order: S1, S4 (after contraband decision), S3, S2, S5. Tune numbers from a table, bot 10 seeds/60 d.
