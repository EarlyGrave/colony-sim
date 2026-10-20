# Quest engine and quest lines

## Engine `[BUILT]` — `sim/quests/quest_log.gd`, `data/quests*.json`, `view/quest_sheet.gd`, flag `balance.q_enabled`
Data quests: `id -> {title, trigger{conds}, start, beats{beat: {text, options{...}, effects, wait, delay}}}`;
loader globs `data/quests_*.json`. Code modules for Q1 (`sim/quests_q1/clerk_note.gd`) and Q2
(`q2_pilgrims.gd`). Answers via `answer_quest`; beats can wait on conditions (AND/OR, `wait_max_days`, F6).
Verbs: flag, letter, mod, items, mood, mood_block, debt_pct (2 % colony / 10 % one-inmate caps),
spawn_colonist, remove_colonist, rename, pollution, gamble (`p`), spawn_enemy (quest-only mimic), standing,
block_standing (strong/weak), ref_block, informant_standing, path, trait, credit, suspicion, defiance.
Conds: min_day, flag/not_flag, quest_done, tier_done, pollution_over, reviews_done, sentence_min,
carry_debt, clues_held, rv_roll_call, block_standing_below/above, contraband_stash_over,
installment_missed, suspicion_over, informant_alive, raids_survived, defiance_over, gear_owned.
Mods read by systems: refine_mult, audit_parts_mult, petition_fee_mult, despair_mult, wave_mult,
essence_drop_mult, review_sponsored. Placeholder `{dead}` = last dead inmate / mimic name.
Text rule: <= 70 chars per line (tests). Replay hash test mid-quest.

## Quest list with status
| id | title | trigger (short) | status |
|---|---|---|---|
| Q1 | The Clerk's Margin Note | first payment + Clerk wanderer | `[BUILT]` code module; cut <= 10 % one inmate |
| Q2 | Pilgrims of the Slag | pollution > 40 % | `[BUILT]` code module; Brother Oto, prayer-site wave |
| Q3 | The Parole Board Loves You | review R2 | `[BUILT]` sponsor / decline / bribe Informant (`review_sponsored`) |
| Q4 | The Gantry Signal | petition P2 | `[IDEA]` not built (folded into the truth beat per economy doc) |
| Q5 | Outpost 7 Does Not Answer | first outpost | `[IDEA]` not built |
| Q6 | The Auditor Visits | audit tier 2 | `[BUILT]` hide (30 plate, waves +20 %) / show (`clue_manifest`) / tour |
| Q7 | The Informant's Ration | — | superseded by Q13 |
| Q8 | What the Creatures Wear | pollution > 70 % + Q2 | `[BUILT]` mimic, study -> `clue_survey_tag`, `essence_drop_mult` |
| Q9 | Next Sentence | shuttle win | `[BUILT]` as meta v2 (see 07); no 3-way Dossier pick |
| Q10 | Warden Maintenance Window | d40 or missed installment | `[BUILT]` PA silence; respect -> `clue_warden_quota` |
| Q11 | The Previous Tenant | sentence >= 2, d6 | `[BUILT]` `clue_loop` |
| Q12 | Rolled Over | sentence >= 3 + Q11 + carried debt | `[BUILT]` true 50 % gamble |
| Q13 | Informant | 6 inmates | `[BUILT]` tolerate / false info / transfer |
| Q14 | Three Forms (+ Q14b Amended Form) | 2 clues + d30 | `[BUILT]` path choice; block leaning shown |
| Q15 | Roll Call | clue C2/C5 + mimic killed inside | `[BUILT]` bury / burn / send tag; `rv_roll_call` |
| Q16 | Lifer's Receipt | d25 + Lifer Standing >= 60 | `[BUILT]` `clue_receipt` |
| Q17 | Reversal (Remission entry) | first cure bill + contamination falling | `[PLANNED]` not built (waits on owner, question 1) |
| S1 | Cohesion Fee | d15 + a block < 30 | `[BUILT]` Pay (`despair_mult` 0.9) / Refuse / Redirect |
| S2 | Pecking Order | spread >= 40 | `[BUILT]` separate / look away / mediate (gamble) |
| S3 | Whisper Network | Q13 tolerated + tier 2 | `[BUILT]` decoy / bait / cut him off |
| S4a/S4b | Unaccounted essence / Stash Inventory | missed installment d20+ / stash > 6 | `[BUILT]` turns contraband on; `clue_buyer` |
| S5 | Old Cells, New Faces | sentence >= 2 + veteran | `[BUILT]` incl. "You were renamed. It did not take." |
| r4 A | Good Behaviour (Submit) | path_submit d28+ | `[BUILT]` `data/quests_s6.json`: bonus pickup, seat list, gear check, scar tax |
| r4 B | Drone Toll (Fight) | path_fight + 1 raid survived (or d36) | `[BUILT]` strip/burn the drone, the pilot, strike vote, scars |
| r4 C | Quiet Freight (Escape) | path_escape d35+ | `[BUILT]` sold name, inspection, courier cage, drone tail |
Bot numbers (10 seeds / 60 d): Q1 10/10, Q2 9/10, Q6 5/10 fire; Q14 only on forced seeds (bots rarely
hold 2 clues by d30). Story-paths test forces each quest.

## Warden PA and letters `[BUILT]` — `view/feed_director.gd`, `view/pa_banner.gd`, `data/flavor.json pa.*`
FeedDirector speaks `pa.<quest>.<beat>` on `quest_beat`, path lines (`pa.path_*`), r4 lines, d40/d50
midgame lines, regulation/fixation lines (inert while flags off), 20 Warden lines from the revelation doc.
Letters go to the letter log / letters panel; notifications stack top-right (max 2).

## Storyteller events `[BUILT]` — `sim/storyteller/storyteller.gd`, `data/events.json`, `data/events_prison.json`, `data/event_chains.json`
One broken link at a time (D15): lightning, sickness, cave-in, wanderer, pod crash, transport drop, toxic
fallout, cargo pod; threat-aware `requires` (dormant / scent_high / wave_pending): `scout_sighting`
(reveals next raid objective + origin), `molt` (dormancy +1 d, mutant band next). Prison chain
(`events_prison.json`): inspection notice, escape rumours, smuggler signal, new prisoners, Metropolis
decree, letter home; crises (`data/crises.json`: siege, dead_lands, last_stand) with options.
Harmful events are suppressed within `quiet_before_wave_ticks` of a wave.
